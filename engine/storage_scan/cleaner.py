"""
Apply a previously recorded scan.

The cleaner refuses to delete anything that did not show up in a scan. That
makes the API safe to expose on localhost: a caller cannot just hand us an
arbitrary path. The contract is:

1. ``POST /api/v1/cleanup/scan`` returns a ``scan_id`` plus per-category
   summaries.
2. ``POST /api/v1/cleanup/apply`` accepts ``scan_id``, the chosen category
   ids, and a ``mode`` of ``recycle`` (default, uses the OS recycle bin via
   :mod:`send2trash` when available) or ``permanent``.

We additionally re-validate each candidate against its category's declared
roots, so a file that moved out of the safe area between scan and apply is
skipped.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

from engine.storage_scan.cleanup_categories import get_category
from engine.storage_scan.scanner import (
    ScanResult,
    _ScanCandidate,
    _within_any_root,
    scan_registry,
)

logger = logging.getLogger(__name__)

try:  # pragma: no cover — optional dep, exercised only on machines that ship it
    from send2trash import send2trash as _send2trash

    HAS_SEND2TRASH = True
except Exception:  # noqa: BLE001 — module import failure must not break engine
    _send2trash = None
    HAS_SEND2TRASH = False


CLEAN_MODE_RECYCLE = "recycle"
CLEAN_MODE_PERMANENT = "permanent"


@dataclass(slots=True)
class CleanResult:
    """Outcome of a single apply call."""

    scan_id: str
    mode: str
    removed: int = 0
    bytes_freed: int = 0
    skipped: int = 0
    errors: list[dict] = field(default_factory=list)
    per_category: dict[str, dict] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "scan_id": self.scan_id,
            "mode": self.mode,
            "removed": int(self.removed),
            "bytes_freed": int(self.bytes_freed),
            "skipped": int(self.skipped),
            "errors": list(self.errors),
            "per_category": {k: dict(v) for k, v in self.per_category.items()},
        }


def _delete_one(path: Path, mode: str) -> None:
    if mode == CLEAN_MODE_RECYCLE and HAS_SEND2TRASH:
        assert _send2trash is not None
        _send2trash(str(path))
        return
    # Permanent or no send2trash available: best-effort unlink.
    path.unlink()


def apply_cleanup(
    *,
    scan_id: str,
    category_ids: Iterable[str] | None,
    mode: str = CLEAN_MODE_RECYCLE,
) -> CleanResult:
    """Delete (or recycle) candidates from a previously recorded scan."""
    mode_norm = (mode or CLEAN_MODE_RECYCLE).strip().lower()
    if mode_norm not in (CLEAN_MODE_RECYCLE, CLEAN_MODE_PERMANENT):
        raise ValueError(f"Unknown cleanup mode: {mode!r}")

    scan: ScanResult | None = scan_registry().get(scan_id)
    if scan is None:
        raise KeyError(f"Unknown or expired scan_id: {scan_id}")

    chosen_ids = set(category_ids or scan.candidates.keys())
    out = CleanResult(scan_id=scan_id, mode=mode_norm)

    for cat_id, candidates in scan.candidates.items():
        if cat_id not in chosen_ids:
            continue
        cat = get_category(cat_id)
        if cat is None:
            out.errors.append({"category": cat_id, "error": "category_not_available"})
            continue
        roots = tuple(Path(r) for r in cat.roots)
        cat_removed = 0
        cat_bytes = 0
        cat_skipped = 0
        for c in candidates:
            path = Path(c.path)
            if not path.exists():
                cat_skipped += 1
                continue
            # Re-validate every candidate against the category roots before
            # touching disk — a symlink swap between scan and apply must not
            # let us delete something outside the safe zone.
            if not _within_any_root(path, roots):
                cat_skipped += 1
                continue
            try:
                size = c.size
                try:
                    # Stat is cheap and corrects size if the file changed.
                    size = path.stat().st_size
                except OSError:
                    pass
                _delete_one(path, mode_norm)
                cat_removed += 1
                cat_bytes += size
            except FileNotFoundError:
                cat_skipped += 1
            except PermissionError as exc:
                out.errors.append({"path": str(path), "error": str(exc)})
                cat_skipped += 1
            except OSError as exc:
                # Locked files on Windows raise OSError; record and continue.
                out.errors.append({"path": str(path), "error": str(exc)})
                cat_skipped += 1
        out.removed += cat_removed
        out.bytes_freed += cat_bytes
        out.skipped += cat_skipped
        out.per_category[cat_id] = {
            "removed": cat_removed,
            "bytes_freed": cat_bytes,
            "skipped": cat_skipped,
        }
    return out


def _purge_test_only(candidates: list[_ScanCandidate]) -> int:
    """Test helper — directly unlink known candidates without registry plumbing."""
    n = 0
    for c in candidates:
        try:
            os.unlink(c.path)
            n += 1
        except OSError:
            pass
    return n
