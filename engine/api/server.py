"""
SentraCore — FastAPI + WebSocket API Server.

Provides REST endpoints for querying system state and WebSocket
connections for real-time telemetry streaming and alert push notifications.

This module defines the FastAPI app factory. The actual server is started
by the main orchestrator using uvicorn.
"""

from __future__ import annotations

import json
import logging
from typing import TYPE_CHECKING

from fastapi import Body, FastAPI, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from engine.storage.paths import CACHE_DIR, storage_summary

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections for live data and alert channels."""

    def __init__(self) -> None:
        self._live_connections: list[WebSocket] = []
        self._alert_connections: list[WebSocket] = []

    async def connect_live(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self._live_connections.append(websocket)
        logger.info("Live WebSocket connected. Total: %d", len(self._live_connections))

    async def connect_alert(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self._alert_connections.append(websocket)
        logger.info(
            "Alert WebSocket connected. Total: %d", len(self._alert_connections)
        )

    def disconnect_live(self, websocket: WebSocket) -> None:
        if websocket in self._live_connections:
            self._live_connections.remove(websocket)
        logger.info(
            "Live WebSocket disconnected. Remaining: %d", len(self._live_connections)
        )

    def disconnect_alert(self, websocket: WebSocket) -> None:
        if websocket in self._alert_connections:
            self._alert_connections.remove(websocket)
        logger.info(
            "Alert WebSocket disconnected. Remaining: %d", len(self._alert_connections)
        )

    async def broadcast_live(self, data: dict) -> None:
        """Broadcast system state to all live connections."""
        if not self._live_connections:
            return
        message = json.dumps(data)
        disconnected = []
        for ws in self._live_connections:
            try:
                await ws.send_text(message)
            except Exception as e:
                logger.debug("Live broadcast failed; dropping client: %r", e)
                disconnected.append(ws)
        for ws in disconnected:
            self.disconnect_live(ws)

    async def broadcast_alert(self, data: dict) -> None:
        """Push alert to all alert connections."""
        if not self._alert_connections:
            return
        message = json.dumps(data)
        disconnected = []
        for ws in self._alert_connections:
            try:
                await ws.send_text(message)
            except Exception as e:
                logger.debug("Alert broadcast failed; dropping client: %r", e)
                disconnected.append(ws)
        for ws in disconnected:
            self.disconnect_alert(ws)

    @property
    def live_count(self) -> int:
        return len(self._live_connections)

    @property
    def alert_count(self) -> int:
        return len(self._alert_connections)


# Global connection manager (shared with the engine)
ws_manager = ConnectionManager()

# Global reference to the engine (set by main.py during startup)
_engine = None


def set_engine(engine) -> None:
    """Register the engine instance for API access."""
    global _engine
    _engine = engine


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""

    app = FastAPI(
        title="SentraCore API",
        description="Local system behavior intelligence API",
        version="0.0.1",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    # CORS: Allow local Flutter app and dev tools
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ----- REST Endpoints -----

    @app.get("/api/v1/health")
    async def health_check():
        """Engine health check."""
        return {
            "status": "running",
            "engine": _engine is not None,
            "websocket_clients": {
                "live": ws_manager.live_count,
                "alerts": ws_manager.alert_count,
            },
        }

    @app.get("/api/v1/status")
    async def get_status():
        """Current system state: latest snapshot, stress, baseline summary."""
        if _engine is None:
            return {"error": "Engine not initialized"}

        return _engine.get_current_state()

    @app.get("/api/v1/processes")
    async def get_processes(
        limit: int = Query(50, ge=1, le=100, description="Max processes to return"),
    ):
        """Top process consumers by sustained impact."""
        if _engine is None:
            return {"error": "Engine not initialized"}

        return {
            "processes": [p.to_dict() for p in _engine.get_top_processes(limit)],
        }

    @app.post("/api/v1/processes/{pid}/action")
    async def post_process_action(pid: int, body: dict = Body(default_factory=dict)):
        """
        Control a tracked process: terminate, kill, or adjust CPU priority
        (lower / normal). Requires sufficient OS permissions.
        """
        if _engine is None:
            return {"ok": False, "error": "Engine not initialized"}

        action = (body.get("action") or "").strip()
        return _engine.process_action(pid, action)

    @app.get("/api/v1/events")
    async def get_events():
        """Recent system events."""
        if _engine is None:
            return {"error": "Engine not initialized"}

        return {
            "events": [e.to_dict() for e in _engine.get_recent_events()],
        }

    @app.get("/api/v1/baseline")
    async def get_baseline():
        """Current baseline statistics."""
        if _engine is None:
            return {"error": "Engine not initialized"}

        return _engine.get_baseline()

    @app.get("/api/v1/preferences")
    async def get_preferences():
        """User-tunable alert thresholds and safeguard process list."""
        if _engine is None:
            return {"error": "Engine not initialized"}

        return _engine.get_user_preferences()

    @app.put("/api/v1/preferences")
    async def put_preferences(body: dict = Body(default_factory=dict)):
        """Update user preferences (persisted to datastore JSON)."""
        if _engine is None:
            return {"ok": False, "error": "Engine not initialized"}

        return _engine.set_user_preferences(body)

    @app.get("/api/v1/alerts")
    async def get_alerts():
        """Recent alerts with Root Cause Analysis."""
        if _engine is None:
            return {"error": "Engine not initialized"}

        return {
            "alerts": [a.to_dict() for a in _engine.alert_manager.get_recent_alerts()],
        }

    # ----- History & storage ----------------------------------------------

    @app.get("/api/v1/history")
    async def get_history(
        from_ts: float | None = Query(
            default=None,
            alias="from",
            description="Inclusive POSIX timestamp; default: now - 24h.",
        ),
        to_ts: float | None = Query(
            default=None,
            alias="to",
            description="Inclusive POSIX timestamp; default: now.",
        ),
        granularity_sec: float | None = Query(
            default=None,
            alias="granularity",
            ge=0,
            description="Minimum spacing between returned samples (seconds).",
        ),
        limit: int | None = Query(
            default=None,
            ge=1,
            le=10000,
            description="Cap on returned samples after downsampling.",
        ),
    ):
        """Persisted telemetry samples between ``from`` and ``to``."""
        if _engine is None:
            return {"error": "Engine not initialized"}
        samples = _engine.history_store.query(
            from_ts=from_ts,
            to_ts=to_ts,
            granularity_sec=granularity_sec,
            limit=limit,
        )
        return {
            "samples": samples,
            "summary": _engine.history_store.summary(),
        }

    @app.delete("/api/v1/history")
    async def delete_history():
        """Wipe the persisted history archive (local action)."""
        if _engine is None:
            return {"ok": False, "error": "Engine not initialized"}
        removed = _engine.history_store.clear()
        return {"ok": True, "files_removed": removed}

    @app.get("/api/v1/storage/info")
    async def get_storage_info():
        """Return on-disk layout, sizes, and retention for the datastore."""
        info: dict = storage_summary()
        if _engine is not None:
            info["history"] = _engine.history_store.summary()
            info["runtime_checkpoint"] = {
                "path": str(_engine.runtime_checkpoint.path),
                "previous_run_unclean": bool(
                    getattr(_engine, "_unclean_previous_shutdown", False)
                ),
            }
        return info

    @app.post("/api/v1/storage/cache/clear")
    async def post_clear_cache():
        """Delete files under ``cache/``. Never touches config/state/history."""
        removed = 0
        bytes_freed = 0
        try:
            for f in CACHE_DIR.rglob("*"):
                if f.is_file():
                    try:
                        bytes_freed += f.stat().st_size
                    except OSError:
                        pass
                    try:
                        f.unlink()
                        removed += 1
                    except OSError:
                        continue
        except OSError as exc:
            return {"ok": False, "error": str(exc)}
        return {"ok": True, "files_removed": removed, "bytes_freed": bytes_freed}

    @app.post("/api/v1/state/reset/baseline")
    async def post_reset_baseline():
        """Reset the behavioral baseline. Engine continues running."""
        if _engine is None:
            return {"ok": False, "error": "Engine not initialized"}
        try:
            _engine.baseline.reset()
            _engine.baseline.persist()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Baseline reset failed: %s", exc)
            return {"ok": False, "error": str(exc)}
        return {"ok": True}

    # ----- WebSocket Endpoints -----

    @app.websocket("/ws/live")
    async def websocket_live(websocket: WebSocket):
        """Real-time system state stream."""
        await ws_manager.connect_live(websocket)
        try:
            while True:
                # Keep connection alive; data is pushed by the engine
                await websocket.receive_text()
        except WebSocketDisconnect:
            pass
        except Exception as e:
            logger.debug("Live WebSocket error: %r", e)
        finally:
            ws_manager.disconnect_live(websocket)

    @app.websocket("/ws/alerts")
    async def websocket_alerts(websocket: WebSocket):
        """Push-based alert notifications."""
        await ws_manager.connect_alert(websocket)
        try:
            while True:
                await websocket.receive_text()
        except WebSocketDisconnect:
            pass
        except Exception as e:
            logger.debug("Alert WebSocket error: %r", e)
        finally:
            ws_manager.disconnect_alert(websocket)

    return app
