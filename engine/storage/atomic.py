"""
Atomic JSON IO helpers.

A power loss or kill mid-write can corrupt a JSON file and lose all of the
state inside it (baseline, preferences, runtime checkpoint). Every writer in
the engine should use :func:`write_json_atomic` so the on-disk file is either
the previous valid version or the new one — never a half-written blob.

Read helpers tolerate empty or partially written files: they return ``None``
(or the caller's default) rather than raising, so the engine can rebuild from
defaults if a previous run was killed mid-flight.
"""

from __future__ import annotations

import json
import logging
import os
import tempfile
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


def write_json_atomic(path: Path, data: Any, *, indent: int = 2) -> None:
    """Serialize ``data`` to ``path`` atomically.

    Writes to a sibling temp file then ``os.replace`` swaps it into place. The
    temp file is created in the destination directory so the swap is on the
    same filesystem and therefore atomic on every supported OS.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=indent, sort_keys=False, ensure_ascii=False)

    fd, tmp_name = tempfile.mkstemp(
        prefix=path.name + ".",
        suffix=".tmp",
        dir=str(path.parent),
    )
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(payload)
            f.flush()
            try:
                os.fsync(f.fileno())
            except OSError:
                # fsync isn't supported on all platforms / filesystems; the
                # os.replace below is still atomic on POSIX and NTFS.
                pass
        os.replace(tmp_path, path)
    except Exception:
        try:
            tmp_path.unlink(missing_ok=True)
        except OSError:
            pass
        raise


def read_json(path: Path, default: Any = None) -> Any:
    """Best-effort JSON read.

    Returns ``default`` if the file is missing, empty, or contains malformed
    JSON. Errors are logged at debug level so a single bad file does not crash
    the engine on startup.
    """
    if not path.is_file():
        return default
    try:
        raw = path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        logger.debug("read_json: failed to read %s: %s", path, exc)
        return default
    if not raw:
        return default
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.warning("read_json: malformed JSON in %s: %s", path, exc)
        return default
