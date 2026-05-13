"""
SentraCore — Persistent storage layout.

Groups all engine-owned data under named subdirectories beneath the writable
``DATASTORE_DIR`` resolved by :mod:`engine.config`. The grouping makes the
on-disk shape easy to reason about and lets operators back up, prune, or
inspect each kind of state independently:

```
<DATASTORE_DIR>/
├── config/      user preferences, engine settings
├── state/       baseline, runtime checkpoint, alerts
├── history/     daily-rotated JSONL telemetry samples
├── logs/        rotated engine logs
├── cache/       safe-to-delete derived artifacts
└── reports/     user-facing exported artifacts
```

The directories are created lazily; call :func:`ensure_layout` once at startup
to materialize them up front.
"""

from __future__ import annotations

from pathlib import Path

from engine.config import DATASTORE_DIR

CONFIG_DIR: Path = DATASTORE_DIR / "config"
STATE_DIR: Path = DATASTORE_DIR / "state"
HISTORY_DIR: Path = DATASTORE_DIR / "history"
LOGS_DIR: Path = DATASTORE_DIR / "logs"
CACHE_DIR: Path = DATASTORE_DIR / "cache"
REPORTS_DIR: Path = DATASTORE_DIR / "reports"

_ALL_DIRS: tuple[Path, ...] = (
    CONFIG_DIR,
    STATE_DIR,
    HISTORY_DIR,
    LOGS_DIR,
    CACHE_DIR,
    REPORTS_DIR,
)


def ensure_layout() -> None:
    """Create the on-disk directory tree if it does not already exist."""
    DATASTORE_DIR.mkdir(parents=True, exist_ok=True)
    for d in _ALL_DIRS:
        d.mkdir(parents=True, exist_ok=True)


def _dir_size_bytes(path: Path) -> int:
    """Recursive byte size for ``path``; returns 0 on any error."""
    total = 0
    try:
        for p in path.rglob("*"):
            if p.is_file():
                try:
                    total += p.stat().st_size
                except OSError:
                    continue
    except OSError:
        return 0
    return total


def storage_summary() -> dict[str, object]:
    """Return on-disk usage for each known subdirectory.

    Used by the API / dashboard to display where engine state lives and how much
    space it currently occupies.
    """
    ensure_layout()
    sections: dict[str, dict[str, object]] = {}
    for name, path in (
        ("config", CONFIG_DIR),
        ("state", STATE_DIR),
        ("history", HISTORY_DIR),
        ("logs", LOGS_DIR),
        ("cache", CACHE_DIR),
        ("reports", REPORTS_DIR),
    ):
        size = _dir_size_bytes(path)
        sections[name] = {
            "path": str(path),
            "bytes": size,
        }
    return {
        "root": str(DATASTORE_DIR),
        "sections": sections,
        "total_bytes": sum(int(s["bytes"]) for s in sections.values()),
    }
