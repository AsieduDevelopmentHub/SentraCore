from __future__ import annotations

import json
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from platform import system
from typing import Literal, TypedDict


EngineStatus = Literal[
    "stopped",
    "starting",
    "health_checking",
    "running",
    "restarting",
    "failed",
]


class EngineConfigJson(TypedDict):
    host: str
    port: int
    bind_host: str
    status: EngineStatus
    last_error: str
    pid: int


def engine_config_path() -> Path:
    """
    Resolve engine-config.json path from executable location.

    This is the single source of truth shared by the desktop app + engine binary.
    PyInstaller (--onefile/--onedir): config lives next to the packaged .exe, not in _MEIPASS.
    """
    override = os.environ.get("SENTRACORE_ENGINE_CONFIG")
    if override:
        return Path(override)
    # Default: use the directory containing the engine executable if it's writable,
    # otherwise fall back to a per-user config path.
    base = Path(sys.executable).resolve().parent
    candidate = base / "engine-config.json"
    try:
        base.mkdir(parents=True, exist_ok=True)
        test = base / ".write_test"
        test.write_text("ok", encoding="utf-8")
        test.unlink(missing_ok=True)
        return candidate
    except OSError:
        pass

    if system().lower() == "windows":
        local = os.environ.get("LOCALAPPDATA")
        if local:
            return Path(local) / "SentraCore" / "engine-config.json"
    if system().lower() == "darwin":
        home = Path.home()
        return (
            home
            / "Library"
            / "Application Support"
            / "SentraCore"
            / "engine-config.json"
        )
    xdg = os.environ.get("XDG_CONFIG_HOME")
    if xdg:
        return Path(xdg) / "sentracore" / "engine-config.json"
    return Path.home() / ".config" / "sentracore" / "engine-config.json"


@dataclass(frozen=True)
class EngineConfig:
    host: str
    port: int
    status: EngineStatus
    bind_host: str | None = None
    last_error: str = ""
    pid: int = 0

    def to_json(self) -> EngineConfigJson:
        return {
            "host": self.host,
            "port": int(self.port),
            "bind_host": self.bind_host or "",
            "status": self.status,
            "last_error": self.last_error,
            "pid": int(self.pid),
        }


def bootstrap_engine_config_if_missing() -> None:
    """
    Ensure engine-config.json exists next to the executable.

    The Flutter app normally creates this from its bundled template on first run.
    If the engine is started first (e.g. Windows installer post-install task), write
    the same defaults so listen allocation can proceed.
    """
    p = engine_config_path()
    if p.exists():
        try:
            if read_engine_config() is not None:
                return
        except Exception:
            pass
    bind_host = "0.0.0.0" if system().lower() == "linux" else "127.0.0.1"
    try:
        port = int(os.environ.get("ENGINE_PORT", "8740"))
    except ValueError:
        port = 8740
    cfg = EngineConfig(
        host="127.0.0.1",
        port=port,
        status="stopped",
        bind_host=bind_host,
        last_error="",
        pid=0,
    )
    write_engine_config_atomic(cfg)


def read_engine_config() -> EngineConfig | None:
    p = engine_config_path()
    try:
        raw = json.loads(p.read_text(encoding="utf-8"))
        if not isinstance(raw, dict):
            return None
        host = str(raw.get("host") or "")
        try:
            port = int(raw.get("port"))
        except (TypeError, ValueError):
            return None
        status = str(raw.get("status") or "stopped")
        bind_raw = raw.get("bind_host")
        bind_s = str(bind_raw).strip() if bind_raw is not None else ""
        bind_host = bind_s or None
        last_error = str(raw.get("last_error") or "")
        pid = int(raw.get("pid") or 0)
        return EngineConfig(
            host=host,
            port=port,
            status=status,  # type: ignore[arg-type]
            bind_host=bind_host,
            last_error=last_error,
            pid=pid,
        )
    except Exception:
        return None


def write_engine_config_atomic(cfg: EngineConfig) -> None:
    p = engine_config_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(cfg.to_json(), indent=2, sort_keys=True)

    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        delete=False,
        dir=str(p.parent),
        prefix=p.name + ".",
        suffix=".tmp",
    ) as f:
        f.write(payload)
        tmp = Path(f.name)

    try:
        tmp.replace(p)
    finally:
        try:
            tmp.unlink(missing_ok=True)
        except Exception:
            pass
