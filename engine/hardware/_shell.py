"""Tiny subprocess helper used by the hardware probes.

Centralises three things every probe wants:

* a hard timeout so a hung tool can't stall the engine,
* stdout/stderr capture without the console flashing on Windows,
* defensive JSON decoding for tools that print noise alongside JSON.

This module never raises on subprocess failure — callers receive ``None``
and decide what "unknown" looks like in their own response.
"""

from __future__ import annotations

import json
import logging
import shutil
import subprocess
import sys
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class ShellResult:
    ok: bool
    stdout: str
    stderr: str
    returncode: int


def _creationflags() -> int:
    """Suppress the console flash on Windows; 0 elsewhere."""
    if sys.platform == "win32":
        return 0x08000000  # CREATE_NO_WINDOW
    return 0


def which(binary: str) -> str | None:
    """Resolve ``binary`` on PATH; ``None`` if it isn't installed."""
    return shutil.which(binary)


def run(
    argv: list[str],
    *,
    timeout: float = 6.0,
    cwd: str | None = None,
) -> ShellResult:
    """Run a process with capture+timeout; never raises."""
    try:
        proc = subprocess.run(  # noqa: S603 — explicit argv list, no shell
            argv,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
            creationflags=_creationflags(),
            check=False,
        )
        return ShellResult(
            ok=proc.returncode == 0,
            stdout=proc.stdout or "",
            stderr=proc.stderr or "",
            returncode=proc.returncode,
        )
    except FileNotFoundError:
        return ShellResult(ok=False, stdout="", stderr="not_found", returncode=-1)
    except subprocess.TimeoutExpired:
        return ShellResult(ok=False, stdout="", stderr="timeout", returncode=-2)
    except OSError as exc:
        return ShellResult(ok=False, stdout="", stderr=str(exc), returncode=-3)


def run_powershell(script: str, *, timeout: float = 6.0) -> ShellResult:
    """Run a PowerShell one-liner; Windows-only callers."""
    return run(
        [
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ],
        timeout=timeout,
    )


def parse_json(blob: str):
    """Best-effort JSON decoder that tolerates wrappers / empty stdout."""
    if not blob or not blob.strip():
        return None
    try:
        return json.loads(blob)
    except json.JSONDecodeError:
        # Some tools wrap JSON in extra log lines; try to locate the payload.
        start = blob.find("{")
        end = blob.rfind("}")
        if start != -1 and end != -1 and end > start:
            try:
                return json.loads(blob[start : end + 1])
            except json.JSONDecodeError:
                pass
        start = blob.find("[")
        end = blob.rfind("]")
        if start != -1 and end != -1 and end > start:
            try:
                return json.loads(blob[start : end + 1])
            except json.JSONDecodeError:
                pass
    return None
