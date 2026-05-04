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
import time

import psutil
import uvicorn

from engine import __app_name__, __version__
from engine.alerts.alert_manager import Alert, AlertManager
from engine.api.server import create_app, set_engine, ws_manager
from engine.baseline.baseline_model import BaselineModel
from engine.buffer.time_series_buffer import TimeSeriesBuffer
from engine.collector.system_collector import SystemCollector
from engine.config import API_HOST, COLLECTION_INTERVAL_SEC, DATASTORE_DIR
from engine.runtime_info import (
    allocate_listen_port,
    clear_engine_runtime,
    write_engine_runtime,
)
from engine.events.event_logger import EventLogger
from engine.normalization.normalizer import NormalizedSnapshot, Normalizer
from engine.process.process_tracker import ProcessImpact, ProcessTracker
from engine.stress.stress_engine import StressEngine, StressResult
from engine.user_preferences import UserPreferences, canonical_process_name
from engine.intelligence.trend_analyzer import TrendAnalyzer, TrendResult
from engine.intelligence.anomaly_detector import AnomalyDetector, AnomalyResult
from engine.intelligence.prediction_engine import PredictionEngine, PredictionResult
from engine.intelligence.stability_index import StabilityCalculator, StabilityIndex

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
        self.trend_analyzer = TrendAnalyzer()
        self.anomaly_detector = AnomalyDetector()
        self.prediction_engine = PredictionEngine()
        self.stress_engine = StressEngine()
        self.stability_calculator = StabilityCalculator()
        self.alert_manager = AlertManager()

        # Current state (updated each cycle)
        self._current_stress: StressResult | None = None
        self._current_normalized: NormalizedSnapshot | None = None
        self._current_trend: TrendResult | None = None
        self._current_anomaly: AnomalyResult | None = None
        self._current_prediction: PredictionResult | None = None
        self._current_stability: StabilityIndex | None = None
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
            "normalized": self._current_normalized.to_dict()
            if self._current_normalized
            else None,
            "trend": self._current_trend.to_dict() if self._current_trend else None,
            "anomaly": self._current_anomaly.to_dict()
            if self._current_anomaly
            else None,
            "prediction": self._current_prediction.to_dict()
            if self._current_prediction
            else None,
            "stress": self._current_stress.to_dict() if self._current_stress else None,
            "stability": self._current_stability.to_dict()
            if self._current_stability
            else None,
            "alert": {
                "total_fired": self.alert_manager.total_alerts,
                "in_cooldown": self.alert_manager.is_in_cooldown,
                "cooldown_total_sec": round(self.alert_manager.cooldown_total_sec, 2),
                "cooldown_remaining_sec": round(
                    self.alert_manager.cooldown_remaining_sec, 2
                ),
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

    def get_top_processes(self, limit: int | None = None) -> list[ProcessImpact]:
        """Return top processes by sustained impact (ranked, capped at ``limit``)."""
        n = 40 if limit is None else int(limit)
        n = max(1, min(n, 100))
        return self.process_tracker.get_top_consumers(n)

    def get_recent_events(self):
        """Return recent system events."""
        return self.event_logger.get_recent_events()

    def process_action(self, pid: int, action: str) -> dict:
        """
        Apply a lifecycle or scheduling action to a process (local engine only).

        Actions: terminate, kill, lower_priority, normal_priority
        """
        allowed = {"terminate", "kill", "lower_priority", "normal_priority"}
        if action not in allowed:
            return {
                "ok": False,
                "error": f"Invalid action; use one of {sorted(allowed)}",
            }

        try:
            proc = psutil.Process(pid)
        except psutil.NoSuchProcess:
            return {"ok": False, "error": "Process not found"}

        try:
            if action == "terminate":
                proc.terminate()
            elif action == "kill":
                proc.kill()
            elif action == "lower_priority":
                if sys.platform == "win32":
                    proc.nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
                else:
                    proc.nice(10)
            elif action == "normal_priority":
                if sys.platform == "win32":
                    proc.nice(psutil.NORMAL_PRIORITY_CLASS)
                else:
                    proc.nice(0)
            return {"ok": True}
        except (psutil.AccessDenied, PermissionError) as exc:
            return {"ok": False, "error": str(exc)}
        except Exception as exc:  # noqa: BLE001 — surface unexpected errors to client
            logger.warning("process_action failed: %s", exc)
            return {"ok": False, "error": str(exc)}

    def get_baseline(self) -> dict:
        """Return baseline statistics."""
        return self.baseline.get_baseline()

    def get_user_preferences(self) -> dict:
        """Return persisted user preferences (alert thresholds, safeguard list)."""
        return UserPreferences.load().to_dict()

    def set_user_preferences(self, body: dict) -> dict:
        """Validate, persist, and return updated user preferences."""
        try:
            prefs = UserPreferences.from_dict(body)
            prefs.save()
        except Exception as exc:
            logger.warning("set_user_preferences failed: %s", exc)
            return {"ok": False, "error": str(exc)}
        return {"ok": True, "preferences": prefs.to_dict()}

    def _apply_safeguard(
        self, prefs: UserPreferences, top_procs: list[ProcessImpact]
    ) -> None:
        """Terminate configured processes when an alert has just fired."""
        if not prefs.safeguard_enabled:
            return
        targets = {
            canonical_process_name(str(n))
            for n in prefs.safeguard_process_names
            if str(n).strip()
        }
        if not targets:
            return
        terminated = 0
        for proc in top_procs[:15]:
            key = canonical_process_name(proc.name)
            if key not in targets:
                continue
            res = self.process_action(proc.pid, "terminate")
            terminated += 1
            logger.warning(
                "Safeguard: terminate %s (pid %s) -> %s",
                proc.name,
                proc.pid,
                res,
            )
            if terminated >= 5:
                break

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
            asyncio.run_coroutine_threadsafe(self._broadcast_alert(alert), self._loop)

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
        logger.info(
            "Collector primed. Starting collection loop (%.1fs interval)...",
            COLLECTION_INTERVAL_SEC,
        )

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

                # 7. Intelligence Layer (Phase 2)
                trend = self.trend_analyzer.analyze(self.buffer)
                self._current_trend = trend

                anomaly = self.anomaly_detector.detect(normalized, self.baseline)
                self._current_anomaly = anomaly

                # 8. Compute stress (Multi-State)
                stress = self.stress_engine.compute(
                    normalized, trend=trend, anomaly=anomaly
                )
                self._current_stress = stress

                # 9. Phase 4: Prediction & Risk
                prediction = self.prediction_engine.predict(trend, normalized)
                self._current_prediction = prediction

                stability = self.stability_calculator.calculate(
                    stress, prediction, anomaly
                )
                self._current_stability = stability

                # 10. Evaluate alerts (user thresholds) + optional safeguard
                top_procs = self.process_tracker.get_top_consumers(5)
                recent_events = self.event_logger.get_recent_events(20)
                prefs = UserPreferences.load()
                alert = self.alert_manager.evaluate(
                    stress, top_procs, recent_events, prefs=prefs
                )
                if alert is not None:
                    self._apply_safeguard(prefs, top_procs)

                # 11. Broadcast via WebSocket
                await self._broadcast_state()

                # Periodic log
                if cycle % 15 == 0:  # Every ~30 seconds
                    logger.info(
                        "Cycle %d | Stability: %.0f/100 (%s) | Risk: %.0f%% | CPU: %.1f%% | Mem: %.1f%% | "
                        "Baseline: %s",
                        cycle,
                        stability.score,
                        stability.state,
                        prediction.risk_score,
                        normalized.cpu_percent_smoothed,
                        normalized.memory_percent_smoothed,
                        "ready" if self.baseline.is_ready else "learning",
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
    # When packaged with PyInstaller + --noconsole, sys.stdout/sys.stderr can be None.
    # In that case, log to a file so the engine can still start and we can diagnose issues.
    log_format = "%(asctime)s | %(levelname)-7s | %(name)s | %(message)s"
    datefmt = "%H:%M:%S"

    handlers: list[logging.Handler] = []
    if getattr(sys, "stdout", None) is not None:
        handlers.append(logging.StreamHandler(sys.stdout))
    else:
        log_dir = DATASTORE_DIR / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(log_dir / "engine.log", encoding="utf-8"))

    logging.basicConfig(
        level=logging.INFO,
        format=log_format,
        datefmt=datefmt,
        handlers=handlers,
    )
    # Reduce noise from third-party loggers
    logging.getLogger("uvicorn").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("fastapi").setLevel(logging.WARNING)


def main() -> None:
    """Entry point for SentraCore engine."""
    _configure_logging()

    # Avoid print() in packaged --noconsole builds (stdout may be None).
    listen_host, listen_port = allocate_listen_port()

    logger.info("%s v%s", __app_name__, __version__)
    logger.info("API: http://%s:%s", listen_host, listen_port)
    logger.info("Docs: http://%s:%s/docs", listen_host, listen_port)
    logger.info("WebSocket: ws://%s:%s/ws/live", listen_host, listen_port)
    logger.info("Interval: %ss", COLLECTION_INTERVAL_SEC)

    # Create engine and register with API
    engine = SentraCoreEngine()
    set_engine(engine)

    # Create FastAPI app
    app = create_app()

    # Configure uvicorn
    # In --noconsole builds, uvicorn's default logging configuration can crash because
    # it assumes sys.stderr is a stream with .isatty(). Disable uvicorn's log config
    # and rely on our own engine logging (file-backed when no console).
    safe_stream = getattr(sys, "stderr", None) is not None
    write_engine_runtime(listen_host, listen_port)
    config = uvicorn.Config(
        app=app,
        host=listen_host,
        port=listen_port,
        log_level="warning",
        access_log=False,
        log_config=None if not safe_stream else uvicorn.config.LOGGING_CONFIG,
    )
    server = uvicorn.Server(config)

    # Handle SIGINT/SIGTERM gracefully
    def signal_handler(signum, frame):
        logger.info("Received signal %d, shutting down...", signum)
        engine.stop()
        server.should_exit = True
        clear_engine_runtime()

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
        clear_engine_runtime()

    try:
        asyncio.run(run_all())
    except KeyboardInterrupt:
        pass
    finally:
        clear_engine_runtime()

    logger.info("%s shut down cleanly.", __app_name__)


if __name__ == "__main__":
    main()
