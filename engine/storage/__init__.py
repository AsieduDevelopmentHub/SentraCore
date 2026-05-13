"""SentraCore storage layout, atomic IO, and migration helpers."""

from engine.storage.atomic import read_json, write_json_atomic
from engine.storage.paths import (
    CACHE_DIR,
    CONFIG_DIR,
    HISTORY_DIR,
    LOGS_DIR,
    REPORTS_DIR,
    STATE_DIR,
    ensure_layout,
    storage_summary,
)

__all__ = [
    "CACHE_DIR",
    "CONFIG_DIR",
    "HISTORY_DIR",
    "LOGS_DIR",
    "REPORTS_DIR",
    "STATE_DIR",
    "ensure_layout",
    "read_json",
    "storage_summary",
    "write_json_atomic",
]
