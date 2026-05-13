"""
Large file browser.

A bounded walk that returns the biggest N files under a path, useful for
"why is my drive full?" investigations. The walk:

* Skips well-known system directories (Windows, Program Files, etc.) by
  default so the user is not nudged into deleting OS-owned content.
* Honors a minimum file size in MiB so tiny files do not flood the result.
* Uses a partial sort (heap) so memory is O(limit), not O(total files).
"""

from __future__ import annotations

import heapq
import logging
import os
import sys
import threading
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class LargeFile:
    path: str
    size: int
    mtime: float
    parent: str

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "size": int(self.size),
            "mtime": float(self.mtime),
            "parent": self.parent,
        }


def _default_excluded_roots() -> set[str]:
    if sys.platform == "win32":
        win = os.environ.get("WINDIR", r"C:\Windows")
        return {
            win.lower(),
            r"c:\program files".lower(),
            r"c:\program files (x86)".lower(),
            r"c:\$recycle.bin".lower(),
            r"c:\system volume information".lower(),
        }
    if sys.platform == "darwin":
        return {
            "/system",
            "/private/var",
            "/usr",
            "/Library/Caches".lower(),
        }
    # Linux & other unix
    return {
        "/proc",
        "/sys",
        "/dev",
        "/run",
        "/snap",
    }


def _is_excluded(path: Path, excluded: set[str]) -> bool:
    try:
        s = str(path.resolve()).lower()
    except OSError:
        return True
    for root in excluded:
        if s == root or s.startswith(root + os.sep) or s.startswith(root + "/"):
            return True
    return False


def find_large_files(
    root: str | Path,
    *,
    min_size_mb: float = 100.0,
    limit: int = 200,
    max_files_scanned: int = 200_000,
    excluded_roots: set[str] | None = None,
    cancel: threading.Event | None = None,
) -> list[LargeFile]:
    """Return up to ``limit`` largest files under ``root``.

    The walk stops after ``max_files_scanned`` file inspections to keep large
    drives bounded; users can narrow the scope by picking a sub-directory.
    """
    base = Path(root).expanduser()
    try:
        base = base.resolve(strict=False)
    except OSError:
        return []
    if not base.exists() or not base.is_dir():
        return []

    threshold = max(0, int(min_size_mb * 1024 * 1024))
    cap = max(1, int(limit))
    excluded = (
        excluded_roots if excluded_roots is not None else _default_excluded_roots()
    )

    # heap holds (size, mtime, path, parent); smallest at index 0 → easy to evict.
    heap: list[tuple[int, float, str, str]] = []
    scanned = 0

    for current_dir, dirs, files in os.walk(base, followlinks=False):
        if cancel is not None and cancel.is_set():
            break
        current = Path(current_dir)
        if _is_excluded(current, excluded):
            dirs[:] = []
            continue

        # Drop sub-directories that would lead into excluded areas.
        dirs[:] = [d for d in dirs if not _is_excluded(current / d, excluded)]

        for name in files:
            scanned += 1
            if scanned > max_files_scanned:
                return _heap_to_sorted(heap)
            full = current / name
            try:
                st = full.stat()
            except OSError:
                continue
            if st.st_size < threshold:
                continue
            entry = (int(st.st_size), float(st.st_mtime), str(full), str(current))
            if len(heap) < cap:
                heapq.heappush(heap, entry)
            elif entry > heap[0]:
                heapq.heapreplace(heap, entry)

    return _heap_to_sorted(heap)


def _heap_to_sorted(heap: list[tuple[int, float, str, str]]) -> list[LargeFile]:
    items = sorted(heap, reverse=True)
    return [
        LargeFile(path=path, size=size, mtime=mtime, parent=parent)
        for (size, mtime, path, parent) in items
    ]
