"""
One-shot migration from the legacy flat datastore to the grouped layout.

Before v0.0.2 the engine wrote ``baseline.json``, ``user_preferences.json``,
and ``logs/engine.log`` directly under ``DATASTORE_DIR``. The new layout puts
them under ``config/``, ``state/``, ``history/``, ``logs/``, ``cache/``, and
``reports/``.

This module is intentionally tolerant: missing files are skipped, the
migration marker makes repeated runs cheap, and any failure is logged rather
than raised so a packaging quirk on one machine cannot keep the engine from
starting.
"""

from __future__ import annotations

import logging
import shutil
from pathlib import Path

from engine.config import DATASTORE_DIR
from engine.storage.paths import (
    CONFIG_DIR,
    STATE_DIR,
    ensure_layout,
)

logger = logging.getLogger(__name__)

_MIGRATION_MARKER: Path = STATE_DIR / ".migrated_v1"


def _move_if_present(src: Path, dst: Path) -> bool:
    """Move ``src`` to ``dst`` if ``src`` exists and ``dst`` does not.

    Returns ``True`` if a move actually happened.
    """
    if not src.exists():
        return False
    if dst.exists():
        # Keep whichever the engine already wrote in the new location; remove
        # the stale legacy copy so future runs cannot reintroduce it.
        try:
            src.unlink()
        except OSError as exc:
            logger.debug("migrate: failed to remove legacy %s: %s", src, exc)
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.move(str(src), str(dst))
    except OSError as exc:
        logger.warning("migrate: failed to move %s -> %s: %s", src, dst, exc)
        return False
    return True


def run_migrations() -> dict[str, object]:
    """Apply outstanding migrations once.

    The function is idempotent: subsequent calls short-circuit on the marker
    file. The returned dict is used by the engine logs and the
    ``/api/v1/storage/info`` endpoint for diagnostics.
    """
    ensure_layout()

    if _MIGRATION_MARKER.exists():
        return {"applied": False, "moved": []}

    moved: list[str] = []

    legacy_baseline = DATASTORE_DIR / "baseline.json"
    if _move_if_present(legacy_baseline, STATE_DIR / "baseline.json"):
        moved.append("baseline.json -> state/baseline.json")

    legacy_prefs = DATASTORE_DIR / "user_preferences.json"
    if _move_if_present(legacy_prefs, CONFIG_DIR / "user_preferences.json"):
        moved.append("user_preferences.json -> config/user_preferences.json")

    try:
        _MIGRATION_MARKER.write_text("ok", encoding="utf-8")
    except OSError as exc:
        logger.warning("migrate: failed to write marker: %s", exc)

    if moved:
        logger.info("Datastore migrated: %s", "; ".join(moved))
    else:
        logger.debug("Datastore already on new layout; nothing to migrate.")

    return {"applied": True, "moved": moved}
