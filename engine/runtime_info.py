"""
SentraCore — Engine HTTP listen address allocation.
"""

from __future__ import annotations

import logging
import socket
from platform import system

from engine.engine_config import (
    EngineConfig,
    read_engine_config,
    write_engine_config_atomic,
)

logger = logging.getLogger(__name__)


def find_first_free_tcp_port(host: str, first_port: int, last_port: int = 65535) -> int:
    """
    Return the first port in [first_port, last_port] that can be bound on `host`.

    Raises RuntimeError if none are free (extremely unlikely on a workstation).
    """
    for port in range(first_port, last_port + 1):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                sock.bind((host, port))
        except OSError:
            continue
        return port
    msg = f"No free TCP port found for {host} in range {first_port}-{last_port}"
    raise RuntimeError(msg)


def _default_bind_host_for_os() -> str:
    return "0.0.0.0" if system().lower() == "linux" else "127.0.0.1"


def allocate_listen_port() -> tuple[str, int]:
    """
    Pick bind host and port for the HTTP API using engine-config.json.

    - Reads starting port from engine-config.json (single source of truth).
    - If port is occupied, increments until a bind succeeds.
    - Updates config only when the bound port differs (status: restarting).
    """
    cfg = read_engine_config()
    if cfg is None:
        raise RuntimeError(
            "engine-config.json missing/invalid. The desktop app must create it before starting the engine."
        )

    bind_host = cfg.bind_host or _default_bind_host_for_os()
    start_port = int(cfg.port)
    port = find_first_free_tcp_port(bind_host, start_port)

    if port != start_port:
        logger.warning("Requested port %s busy; rebinding to %s.", start_port, port)
        write_engine_config_atomic(
            EngineConfig(
                host=cfg.host,
                port=port,
                status="restarting",
                bind_host=bind_host,
                pid=cfg.pid,
                last_error=cfg.last_error,
            )
        )

    return bind_host, port
