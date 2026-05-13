"""
Cleanup scanner.

Walks the declared cleanup categories, computes how much space each would
free, and returns a sample of file paths so the dashboard can preview before
the user clicks "delete". The scan is read-only — nothing is ever removed
here, only inspected.

Each scan is identified by an opaque ``scan_id`` (UUID) and stored in the
in-memory scan registry. The cleaner module refuses to delete anything that
was not part of a stored scan, which closes the door on arbitrary path
deletion via the API.
"""

from __future__ import annotations

import logging
import os
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path

from engine.storage_scan.cleanup_categories import (
    CleanupCategory,
    available_categories,
    get_category,
    os_label,
)

logger = logging.getLogger(__name__)


# Per-category guard rails — prevent a runaway walk in pathological folders.
DEFAULT_MAX_FILES_PER_CATEGORY = 25_000
DEFAULT_MAX_BYTES_PER_CATEGORY = 64 * 1024 * 1024 * 1024  # 64 GiB
DEFAULT_SAMPLE_PER_CATEGORY = 20


@dataclass(slots=True)
class _ScanCandidate:
    """One file the scanner identified as eligible for cleanup."""

    path: str
    size: int
    mtime: float
    category_id: str


@dataclass(slots=True)
class CategoryScanResult:
    """Per-category scan summary returned to the API."""

    id: str
    label: str
    description: str
    bytes: int = 0
    file_count: int = 0
    roots: tuple[str, ...] = field(default_factory=tuple)
    samples: list[dict] = field(default_factory=list)
    requires_admin: bool = False
    error: str | None = None

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "label": self.label,
            "description": self.description,
            "bytes": int(self.bytes),
            "file_count": int(self.file_count),
            "roots": list(self.roots),
            "samples": list(self.samples),
            "requires_admin": bool(self.requires_admin),
            "error": self.error,
        }


@dataclass(slots=True)
class ScanResult:
    """Aggregated scan result; held in the scan registry for later use."""

    scan_id: str
    started_at: float
    completed_at: float
    os: str
    categories: list[CategoryScanResult]
    candidates: dict[str, list[_ScanCandidate]] = field(default_factory=dict)

    @property
    def total_bytes(self) -> int:
        return sum(c.bytes for c in self.categories)

    @property
    def total_files(self) -> int:
        return sum(c.file_count for c in self.categories)

    def to_dict(self) -> dict:
        return {
            "scan_id": self.scan_id,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "os": self.os,
            "total_bytes": self.total_bytes,
            "total_files": self.total_files,
            "categories": [c.to_dict() for c in self.categories],
        }


# --------------------------------------------------------------------------- #
# Scan registry — small in-memory map; bounded so stale results don't pile up.
# --------------------------------------------------------------------------- #


class ScanRegistry:
    """Thread-safe in-memory store for completed scans.

    The cleaner consults this registry to validate that a delete request maps
    back to files we identified during a scan. Without that handshake an
    attacker (or buggy caller) could ask the API to delete arbitrary paths.
    """

    def __init__(self, capacity: int = 16, ttl_sec: int = 30 * 60) -> None:
        self._capacity = max(1, int(capacity))
        self._ttl_sec = max(60, int(ttl_sec))
        self._lock = threading.Lock()
        self._scans: dict[str, ScanResult] = {}

    def put(self, result: ScanResult) -> None:
        with self._lock:
            self._scans[result.scan_id] = result
            self._evict_locked()

    def get(self, scan_id: str) -> ScanResult | None:
        with self._lock:
            self._evict_locked()
            return self._scans.get(scan_id)

    def all_ids(self) -> list[str]:
        with self._lock:
            return list(self._scans.keys())

    def _evict_locked(self) -> None:
        now = time.time()
        # Drop anything past TTL.
        stale = [
            sid
            for sid, r in self._scans.items()
            if (now - r.completed_at) > self._ttl_sec
        ]
        for sid in stale:
            self._scans.pop(sid, None)
        # Drop oldest first if over capacity.
        if len(self._scans) > self._capacity:
            for sid in sorted(self._scans, key=lambda s: self._scans[s].completed_at)[
                : len(self._scans) - self._capacity
            ]:
                self._scans.pop(sid, None)


_registry = ScanRegistry()


def scan_registry() -> ScanRegistry:
    """Module-level singleton used by the cleaner."""
    return _registry


# --------------------------------------------------------------------------- #
# Walk implementation
# --------------------------------------------------------------------------- #


def _within_any_root(path: Path, roots: tuple[Path, ...]) -> bool:
    """Cheap containment check used during scan + delete.

    Tries a fast string prefix comparison first (no syscalls), and only falls
    back to ``Path.resolve()`` when the prefix check fails — which only
    matters for symlinks the caller deliberately followed. ``os.walk`` is
    invoked with ``followlinks=False``, so the slow path is rare in practice.
    """
    p_str = str(path)
    for root in roots:
        r_str = str(root)
        if p_str == r_str or p_str.startswith(r_str + os.sep):
            return True
    try:
        resolved = path.resolve(strict=False)
    except OSError:
        return False
    for root in roots:
        try:
            resolved.relative_to(root)
            return True
        except ValueError:
            continue
    return False


def _walk_category(
    cat: CleanupCategory,
    *,
    max_files: int,
    max_bytes: int,
    sample_size: int,
    cancel: threading.Event | None,
) -> tuple[CategoryScanResult, list[_ScanCandidate]]:
    out = CategoryScanResult(
        id=cat.id,
        label=cat.label,
        description=cat.description,
        roots=tuple(str(r) for r in cat.roots),
        requires_admin=cat.requires_admin,
    )
    if not cat.roots:
        return out, []

    now = time.time()
    min_age_sec = cat.min_age_days * 86_400 if cat.min_age_days else 0
    samples: list[_ScanCandidate] = []
    candidates: list[_ScanCandidate] = []

    seen_files = 0
    total_bytes = 0

    def cancelled() -> bool:
        return cancel is not None and cancel.is_set()

    for root in cat.roots:
        if cancelled():
            break
        if not root.is_dir():
            continue
        root_str = str(root)
        root_sep_count = root_str.count(os.sep)

        for current_dir, dirs, files in os.walk(root, followlinks=False):
            if cancelled() or seen_files >= max_files or total_bytes >= max_bytes:
                break

            # String-based depth check — avoids a stat per directory.
            depth = current_dir.count(os.sep) - root_sep_count
            if depth >= cat.max_depth:
                dirs[:] = []

            for name in files:
                if cancelled() or seen_files >= max_files or total_bytes >= max_bytes:
                    break
                full = Path(current_dir) / name
                try:
                    st = full.stat()
                except OSError:
                    continue
                if min_age_sec and (now - st.st_mtime) < min_age_sec:
                    continue
                if not _within_any_root(full, cat.roots):
                    # Skipped: symlinks pointing outside the declared roots.
                    continue

                cand = _ScanCandidate(
                    path=str(full),
                    size=int(st.st_size),
                    mtime=float(st.st_mtime),
                    category_id=cat.id,
                )
                candidates.append(cand)
                total_bytes += cand.size
                seen_files += 1

                if len(samples) < sample_size or cand.size > samples[-1].size:
                    samples.append(cand)
                    samples.sort(key=lambda c: c.size, reverse=True)
                    del samples[sample_size:]

    out.bytes = total_bytes
    out.file_count = seen_files
    out.samples = [
        {
            "path": c.path,
            "size": c.size,
            "mtime": c.mtime,
        }
        for c in samples
    ]
    return out, candidates


def run_scan(
    category_ids: list[str] | None = None,
    *,
    max_files_per_category: int = DEFAULT_MAX_FILES_PER_CATEGORY,
    max_bytes_per_category: int = DEFAULT_MAX_BYTES_PER_CATEGORY,
    sample_per_category: int = DEFAULT_SAMPLE_PER_CATEGORY,
    cancel: threading.Event | None = None,
) -> ScanResult:
    """Run a synchronous cleanup scan and register the result.

    ``category_ids`` filters which categories are walked; ``None`` means all
    categories applicable to the current OS.
    """
    started = time.time()
    selected: list[CleanupCategory]
    if category_ids:
        selected = []
        for cid in category_ids:
            cat = get_category(cid)
            if cat is not None:
                selected.append(cat)
    else:
        selected = available_categories()

    cat_results: list[CategoryScanResult] = []
    candidate_map: dict[str, list[_ScanCandidate]] = {}
    for cat in selected:
        try:
            res, cands = _walk_category(
                cat,
                max_files=max_files_per_category,
                max_bytes=max_bytes_per_category,
                sample_size=sample_per_category,
                cancel=cancel,
            )
        except Exception as exc:  # noqa: BLE001 — scan should not crash engine
            logger.warning("scan %s failed: %s", cat.id, exc)
            res = CategoryScanResult(
                id=cat.id,
                label=cat.label,
                description=cat.description,
                roots=tuple(str(r) for r in cat.roots),
                error=str(exc),
            )
            cands = []
        cat_results.append(res)
        if cands:
            candidate_map[cat.id] = cands

    result = ScanResult(
        scan_id=uuid.uuid4().hex,
        started_at=started,
        completed_at=time.time(),
        os=os_label(),
        categories=cat_results,
        candidates=candidate_map,
    )
    _registry.put(result)
    return result
