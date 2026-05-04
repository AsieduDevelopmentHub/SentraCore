"""
SentraCore — Engine HTTP listen address persisted for local clients.

The dashboard discovers which port the engine bound when 8740 is occupied.
"""

from __future__ import annotations

import json
import logging
import socket
from pathlib import Path

from engine.config import API_HOST, API_PORT, DATASTORE_DIR

logger = logging.getLogger(__name__)

RUNTIME_FILE: Path = DATASTORE_DIR / "engine_runtime.json"


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


def write_engine_runtime(http_host: str, http_port: int) -> None:
    """Write listen address for local UIs (Flutter) to discover quickly."""
    RUNTIME_FILE.parent.mkdir(parents=True, exist_ok=True)
    payload = {"http_host": http_host, "http_port": http_port}
    RUNTIME_FILE.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    logger.info("Wrote engine runtime: %s", RUNTIME_FILE)


def clear_engine_runtime() -> None:
    """Remove runtime file on clean shutdown (best-effort)."""
    try:
        RUNTIME_FILE.unlink(missing_ok=True)
    except OSError as exc:
        logger.debug("Could not remove runtime file: %s", exc)


def allocate_listen_port() -> tuple[str, int]:
    """
    Pick host and port for the HTTP API.

    Starts at API_PORT and increments until a bind succeeds.
    """
    host = API_HOST
    port = find_first_free_tcp_port(host, API_PORT)
    if port != API_PORT:
        logger.warning(
            "Default port %s busy; listening on %s instead (local-only discovery).",
            API_PORT,
            port,
        )
    return host, port
