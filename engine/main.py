"""
SentraCore — Main Engine Orchestrator.

Ties together all modules into a continuous monitoring loop:
1. Collect system telemetry (SystemCollector)
2. Normalize data (Normalizer)
3. Push to time-series buffers (TimeSeriesBuffer)
4. Update baseline model (BaselineModel)
5. Track process impact (ProcessTracker)
6. Detect system events (EventLogger)
7. Compute stress score (StressEngine)
8. Evaluate alert conditions (AlertManager)
9. Broadcast state via WebSocket

The API server runs in a background thread via uvicorn.
"""

from __future__ import annotations

import asyncio
import logging
import signal
import sys
import threading
import time

import uvicorn

from engine import __app_name__, __version__
from engine.alerts.alert_manager import Alert, AlertManager
from engine.api.server import create_app, set_engine, ws_manager
from engine.baseline.baseline_model import BaselineModel
from engine.buffer.time_series_buffer import TimeSeriesBuffer
from engine.collector.system_collector import SystemCollector
from engine.config import API_HOST, API_PORT, COLLECTION_INTERVAL_SEC
from engine.events.event_logger import EventLogger
from engine.normalization.normalizer import NormalizedSnapshot, Normalizer
from engine.process.process_tracker import ProcessImpact, ProcessTracker
from engine.stress.stress_engine import StressEngine, StressResult

logger = logging.getLogger(__name__)


class SentraCoreEngine:
    """
    Core engine that orchestrates all monitoring modules.

    Provides methods for the API layer to query current state.
    """

    def __init__(self) -> None:
        # Initialize all modules
        self.collector = SystemCollector()
        self.normalizer = Normalizer()
        self.buffer = TimeSeriesBuffer()
        self.baseline = BaselineModel()
        self.process_tracker = ProcessTracker()
        self.event_logger = EventLogger()
        self.stress_engine = StressEngine()
        self.alert_manager = AlertManager()

        # Current state (updated each cycle)
        self._current_stress: StressResult | None = None
        self._current_normalized: NormalizedSnapshot | None = None
        self._last_alert: Alert | None = None

        # Control
        self._running = False
        self._loop: asyncio.AbstractEventLoop | None = None

    def get_current_state(self) -> dict:
        """Return current system state for the API."""
        latest = self.buffer.get_latest()

        state = {
            "engine": {
                "version": __version__,
                "uptime_samples": self.buffer.long_count,
                "baseline_ready": self.baseline.is_ready,
                "baseline_samples": self.baseline.sample_count,
            },
            "snapshot": latest.to_dict() if latest else None,
            "normalized": self._current_normalized.to_dict() if self._current_normalized else None,
            "stress": self._current_stress.to_dict() if self._current_stress else None,
            "alert": {
                "total_fired": self.alert_manager.total_alerts,
                "in_cooldown": self.alert_manager.is_in_cooldown,
                "consecutive_high": self.alert_manager.consecutive_high_count,
                "last_alert": self._last_alert.to_dict() if self._last_alert else None,
            },
            "buffers": {
                "short": {
                    "count": self.buffer.short_count,
                    "capacity": self.buffer.short_capacity,
                },
                "long": {
                    "count": self.buffer.long_count,
                    "capacity": self.buffer.long_capacity,
                },
            },
        }
        return state

    def get_top_processes(self) -> list[ProcessImpact]:
        """Return top processes by sustained impact."""
        return self.process_tracker.get_top_consumers()

    def get_recent_events(self):
        """Return recent system events."""
        return self.event_logger.get_recent_events()

    def get_baseline(self) -> dict:
        """Return baseline statistics."""
        return self.baseline.get_baseline()

    async def _broadcast_state(self) -> None:
        """Broadcast current state to WebSocket clients."""
        try:
            state = self.get_current_state()
            await ws_manager.broadcast_live(state)
        except Exception as exc:
            logger.debug("WebSocket broadcast error: %s", exc)

    async def _broadcast_alert(self, alert: Alert) -> None:
        """Push alert to WebSocket alert subscribers."""
        try:
            await ws_manager.broadcast_alert(alert.to_dict())
        except Exception as exc:
            logger.debug("Alert broadcast error: %s", exc)

    def _on_alert(self, alert: Alert) -> None:
        """Callback when AlertManager fires an alert."""
        self._last_alert = alert
        # Schedule async broadcast from sync context
        if self._loop and self._loop.is_running():
            asyncio.run_coroutine_threadsafe(
                self._broadcast_alert(alert), self._loop
            )

    async def run(self) -> None:
        """
        Main engine loop.

        Runs continuously at COLLECTION_INTERVAL_SEC, executing the
        full telemetry pipeline each cycle.
        """
        self._running = True
        self._loop = asyncio.get_event_loop()

        # Register alert callback
        self.alert_manager.register_callback(self._on_alert)

        # Prime CPU measurement
        self.collector.prime()
        logger.info("Collector primed. Starting collection loop (%.1fs interval)...", COLLECTION_INTERVAL_SEC)

        # Wait one interval for CPU delta to be meaningful
        await asyncio.sleep(COLLECTION_INTERVAL_SEC)

        cycle = 0
        while self._running:
            cycle_start = time.time()
            cycle += 1

            try:
                # 1. Collect raw telemetry
                snapshot = self.collector.collect()

                # 2. Normalize data
                normalized = self.normalizer.normalize(snapshot)
                self._current_normalized = normalized

                # 3. Push to buffers
                self.buffer.push(snapshot)

                # 4. Update baseline
                self.baseline.update(normalized)

                # 5. Track processes
                self.process_tracker.update(snapshot.processes)

                # 6. Detect events
                self.event_logger.analyze(snapshot, normalized)

                # 7. Compute stress
                stress = self.stress_engine.compute(normalized)
                self._current_stress = stress

                # 8. Evaluate alerts
                top_procs = self.process_tracker.get_top_consumers(5)
                self.alert_manager.evaluate(stress, top_procs)

                # 9. Broadcast via WebSocket
                await self._broadcast_state()

                # Periodic log
                if cycle % 15 == 0:  # Every ~30 seconds
                    logger.info(
                        "Cycle %d | Stress: %.0f (%s) | CPU: %.1f%% | Mem: %.1f%% | "
                        "Disk: %.0f ops/s | Baseline: %s (%d samples) | Events: %d",
                        cycle,
                        stress.score,
                        stress.level,
                        normalized.cpu_percent_smoothed,
                        normalized.memory_percent_smoothed,
                        normalized.disk_total_ops_per_sec,
                        "ready" if self.baseline.is_ready else "learning",
                        self.baseline.sample_count,
                        self.event_logger.event_count,
                    )

            except Exception as exc:
                logger.error("Engine cycle %d error: %s", cycle, exc, exc_info=True)

            # Sleep for the remainder of the interval
            elapsed = time.time() - cycle_start
            sleep_time = max(0, COLLECTION_INTERVAL_SEC - elapsed)
            if sleep_time > 0:
                await asyncio.sleep(sleep_time)

        # Persist baseline on shutdown
        self.baseline.persist()
        logger.info("Engine stopped. Baseline persisted.")

    def stop(self) -> None:
        """Signal the engine to stop."""
        self._running = False
        logger.info("Engine stop requested.")


def _configure_logging() -> None:
    """Configure structured logging for the engine."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
        datefmt="%H:%M:%S",
        handlers=[logging.StreamHandler(sys.stdout)],
    )
    # Reduce noise from third-party loggers
    logging.getLogger("uvicorn").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("fastapi").setLevel(logging.WARNING)


def main() -> None:
    """Entry point for SentraCore engine."""
    _configure_logging()

    print(f"\n{'='*60}")
    print(f"  {__app_name__} v{__version__}")
    print(f"  Local System Behavior Intelligence Layer")
    print(f"{'='*60}")
    print(f"  API:       http://{API_HOST}:{API_PORT}")
    print(f"  Docs:      http://{API_HOST}:{API_PORT}/docs")
    print(f"  WebSocket: ws://{API_HOST}:{API_PORT}/ws/live")
    print(f"  Interval:  {COLLECTION_INTERVAL_SEC}s")
    print(f"{'='*60}\n")

    # Create engine and register with API
    engine = SentraCoreEngine()
    set_engine(engine)

    # Create FastAPI app
    app = create_app()

    # Configure uvicorn
    config = uvicorn.Config(
        app=app,
        host=API_HOST,
        port=API_PORT,
        log_level="warning",
        access_log=False,
    )
    server = uvicorn.Server(config)

    # Handle SIGINT/SIGTERM gracefully
    def signal_handler(signum, frame):
        logger.info("Received signal %d, shutting down...", signum)
        engine.stop()
        server.should_exit = True

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Run engine and API server together
    async def run_all():
        # Start API server as a background task
        api_task = asyncio.create_task(server.serve())

        # Run the engine (main loop)
        engine_task = asyncio.create_task(engine.run())

        # Wait for either to finish
        done, pending = await asyncio.wait(
            [api_task, engine_task],
            return_when=asyncio.FIRST_COMPLETED,
        )

        # Cancel remaining tasks
        for task in pending:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

    try:
        asyncio.run(run_all())
    except KeyboardInterrupt:
        pass

    print(f"\n{__app_name__} shut down cleanly.")


if __name__ == "__main__":
    main()
