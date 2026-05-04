"""
SentraCore — User-tunable alert thresholds and safeguard (auto-terminate) list.

Persisted to JSON under the writable datastore so the dashboard and engine share
the same file via REST sync.
"""

from __future__ import annotations

import json
import logging
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from engine.config import DATASTORE_DIR

logger = logging.getLogger(__name__)

PREFS_PATH: Path = DATASTORE_DIR / "user_preferences.json"


def _clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def _parse_name_list(raw: Any) -> list[str]:
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    if isinstance(raw, str):
        parts = re.split(r"[\n,;]+", raw)
        return [p.strip() for p in parts if p.strip()]
    return []


@dataclass
class UserPreferences:
    """
    Alert thresholds use the same 0–100 pressure signals as the stress engine
    (CPU %, memory pressure %, disk I/O pressure %).
    """

    alert_cpu_percent: float = 85.0
    alert_memory_percent: float = 85.0
    alert_disk_pressure: float = 80.0
    safeguard_enabled: bool = False
    safeguard_process_names: list[str] = field(default_factory=list)

    @classmethod
    def default(cls) -> UserPreferences:
        """In-memory defaults (no disk read)."""
        return cls()

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["safeguard_process_names"] = list(self.safeguard_process_names)
        return d

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> UserPreferences:
        raw_names = _parse_name_list(data.get("safeguard_process_names"))
        names = sorted({canonical_process_name(n) for n in raw_names if str(n).strip()})
        return cls(
            alert_cpu_percent=_clamp(
                float(data.get("alert_cpu_percent", 85.0)), 1.0, 100.0
            ),
            alert_memory_percent=_clamp(
                float(data.get("alert_memory_percent", 85.0)), 1.0, 100.0
            ),
            alert_disk_pressure=_clamp(
                float(data.get("alert_disk_pressure", 80.0)), 1.0, 100.0
            ),
            safeguard_enabled=bool(data.get("safeguard_enabled", False)),
            safeguard_process_names=names,
        )

    def save(self) -> None:
        PREFS_PATH.parent.mkdir(parents=True, exist_ok=True)
        PREFS_PATH.write_text(
            json.dumps(self.to_dict(), indent=2),
            encoding="utf-8",
        )

    @classmethod
    def load(cls) -> UserPreferences:
        if not PREFS_PATH.is_file():
            return cls.default()
        try:
            raw = json.loads(PREFS_PATH.read_text(encoding="utf-8"))
            if not isinstance(raw, dict):
                return cls.default()
            return cls.from_dict(raw)
        except Exception as exc:
            logger.warning("Failed to load user preferences: %s", exc)
            return cls.default()


def canonical_process_name(name: str) -> str:
    """Normalize for comparison (e.g. user enters 'chrome' or 'Chrome.exe')."""
    n = name.strip().lower()
    if not n:
        return ""
    return n if n.endswith(".exe") else f"{n}.exe"
