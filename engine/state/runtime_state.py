"""
SentraCore — Runtime state checkpoint.

Captures a small, lossless slice of the engine's in-memory state so that an
unclean stop (Task Manager kill, power loss, panic) does not erase what the
operator was looking at moments earlier. On the next startup the engine reads
the checkpoint and seeds the alert manager + "current" cached fields, which
keeps the dashboard's "Last alert", stability score, and recent breach list
populated immediately instead of waiting for new telemetry to flow in.

The checkpoint is intentionally small and JSON-encoded (atomic write) — the
deep history lives in :mod:`engine.history.history_store`.
"""

from __future__ import annotations

import logging
import time
from pathlib import Path
from typing import Any

from engine.config import STATE_SUBDIR
from engine.storage.atomic import read_json, write_json_atomic

logger = logging.getLogger(__name__)


class RuntimeCheckpoint:
    """Reads / writes ``state/runtime.json``.

    The file holds:

    * ``last_clean_shutdown`` — ``True`` if the engine wrote a final
      checkpoint during shutdown; ``False`` if the previous run was killed.
    * ``last_checkpoint_at`` — POSIX seconds when the checkpoint was written.
    * ``alerts_recent`` — most recent alerts (``Alert.to_dict`` payloads).
    * ``last_stress``, ``last_stability``, ``last_normalized``,
      ``last_prediction``, ``last_anomaly`` — latest computed values.
    """

    def __init__(self, path: Path = STATE_SUBDIR / "runtime.json") -> None:
        self._path = path

    @property
    def path(self) -> Path:
        return self._path

    # ------------------------------------------------------------------ read

    def load(self) -> dict[str, Any]:
        """Return the most recent checkpoint as a plain dict.

        Always returns a dict; missing keys are filled with ``None`` so callers
        can rely on the shape.
        """
        raw = read_json(self._path, default={})
        if not isinstance(raw, dict):
            raw = {}
        return {
            "last_clean_shutdown": bool(raw.get("last_clean_shutdown", False)),
            "last_checkpoint_at": (
                float(raw["last_checkpoint_at"])
                if isinstance(raw.get("last_checkpoint_at"), (int, float))
                else None
            ),
            "alerts_recent": list(raw.get("alerts_recent") or []),
            "last_stress": raw.get("last_stress"),
            "last_stability": raw.get("last_stability"),
            "last_normalized": raw.get("last_normalized"),
            "last_prediction": raw.get("last_prediction"),
            "last_anomaly": raw.get("last_anomaly"),
        }

    # ----------------------------------------------------------------- write

    def write(
        self,
        *,
        alerts_recent: list[dict],
        last_stress: dict | None,
        last_stability: dict | None,
        last_normalized: dict | None,
        last_prediction: dict | None,
        last_anomaly: dict | None,
        clean_shutdown: bool,
    ) -> None:
        """Persist the current view of the engine's hot state."""
        payload = {
            "schema": 1,
            "last_clean_shutdown": bool(clean_shutdown),
            "last_checkpoint_at": time.time(),
            "alerts_recent": list(alerts_recent or []),
            "last_stress": last_stress,
            "last_stability": last_stability,
            "last_normalized": last_normalized,
            "last_prediction": last_prediction,
            "last_anomaly": last_anomaly,
        }
        try:
            write_json_atomic(self._path, payload)
        except OSError as exc:
            logger.warning("runtime checkpoint write failed: %s", exc)

    def mark_dirty_startup(self) -> bool:
        """Flip ``last_clean_shutdown`` to False at startup.

        Returns ``True`` if the previous run looked unclean (file existed but
        the flag was False, or the file was missing entirely). Callers can use
        this for first-cycle logging.
        """
        data = self.load()
        was_unclean = not data.get("last_clean_shutdown", False)
        try:
            data["last_clean_shutdown"] = False
            data["last_checkpoint_at"] = time.time()
            write_json_atomic(self._path, data)
        except OSError as exc:
            logger.debug("mark_dirty_startup: %s", exc)
        return was_unclean
