"""
SentraCore — Hardware health.

Three probes (:mod:`cpu_health`, :mod:`memory_health`, :mod:`disk_health`)
sample CPU, RAM, and storage devices and grade each one ``healthy /
warning / critical / unknown``. The package-level :func:`collect_health`
aggregates the probes, applies a small TTL cache so the API can be hit
frequently without re-spawning subprocesses, and exposes a single
JSON-friendly dict to the API layer.

Each probe is defensive: hardware introspection is full of OS-specific
quirks (no temps on Windows non-admin, smartctl missing on consumer
machines, etc.). When information cannot be obtained, the probe reports
status ``unknown`` with a hint — it does **not** raise.
"""

from __future__ import annotations

import copy
import logging
import threading
import time
from dataclasses import dataclass

from engine.hardware.cpu_health import probe_cpu
from engine.hardware.disk_health import probe_disks
from engine.hardware.memory_health import probe_memory

logger = logging.getLogger(__name__)


STATUS_HEALTHY = "healthy"
STATUS_WARNING = "warning"
STATUS_CRITICAL = "critical"
STATUS_UNKNOWN = "unknown"

_STATUS_RANK = {
    STATUS_HEALTHY: 0,
    STATUS_UNKNOWN: 1,
    STATUS_WARNING: 2,
    STATUS_CRITICAL: 3,
}


def worst_status(statuses: list[str]) -> str:
    """Return the worst status across a list (critical > warning > unknown > healthy)."""
    if not statuses:
        return STATUS_UNKNOWN
    return max(statuses, key=lambda s: _STATUS_RANK.get(s, 1))


@dataclass(slots=True)
class _CacheEntry:
    payload: dict
    expires_at: float


_cache_lock = threading.Lock()
_cache: _CacheEntry | None = None
_DEFAULT_TTL_SEC = 30.0


def collect_health(*, ttl_sec: float = _DEFAULT_TTL_SEC, refresh: bool = False) -> dict:
    """Aggregate CPU, memory, and disk probes.

    Result is cached for ``ttl_sec`` seconds so repeated UI polls don't
    re-spawn subprocesses; pass ``refresh=True`` to bypass the cache.
    """
    global _cache
    now = time.time()
    if not refresh:
        with _cache_lock:
            entry = _cache
        if entry is not None and entry.expires_at > now:
            return entry.payload

    cpu = _safe(probe_cpu, "cpu")
    memory = _safe(probe_memory, "memory")
    disks = _safe(probe_disks, "disks")

    components = {"cpu": cpu, "memory": memory, "disks": disks}
    overall = worst_status(
        [c.get("status", STATUS_UNKNOWN) for c in components.values()]
    )
    payload = {
        "ts": now,
        "overall": overall,
        "components": components,
    }
    with _cache_lock:
        _cache = _CacheEntry(payload=payload, expires_at=now + max(1.0, ttl_sec))
    return payload


_EMPTY_COMPONENT: dict = {
    "status": STATUS_UNKNOWN,
    "issues": [],
    "metrics": {},
    "items": [],
}


def collect_component(target: str, *, ttl_sec: float = _DEFAULT_TTL_SEC) -> dict:
    """Run one hardware probe and merge the result into the TTL cache.

    ``target`` accepts ``cpu``, ``memory``, ``disk``, or ``disks`` (disk → disks).
    Other components are preserved from the last cached full snapshot when
    available; otherwise they start as *unknown* until refreshed.
    """
    global _cache
    norm = target.strip().lower()
    aliases = {"cpu": "cpu", "memory": "memory", "disks": "disks", "disk": "disks"}
    key = aliases.get(norm)
    if key is None:
        raise ValueError(
            f"invalid hardware test target {target!r}; use cpu, memory, or disk"
        )

    now = time.time()
    with _cache_lock:
        entry = _cache
    if entry is not None:
        payload = copy.deepcopy(entry.payload)
        comps = payload.setdefault("components", {})
        if not isinstance(comps, dict):
            payload["components"] = {}
            comps = payload["components"]
        for attr in ("cpu", "memory", "disks"):
            comps.setdefault(attr, copy.deepcopy(_EMPTY_COMPONENT))
    else:
        payload = {
            "ts": now,
            "overall": STATUS_UNKNOWN,
            "components": {
                "cpu": copy.deepcopy(_EMPTY_COMPONENT),
                "memory": copy.deepcopy(_EMPTY_COMPONENT),
                "disks": copy.deepcopy(_EMPTY_COMPONENT),
            },
        }

    probes = {"cpu": probe_cpu, "memory": probe_memory, "disks": probe_disks}
    payload["components"][key] = _safe(probes[key], key)
    payload["overall"] = worst_status(
        [
            c.get("status", STATUS_UNKNOWN)
            for c in payload["components"].values()
            if isinstance(c, dict)
        ]
    )
    payload["ts"] = time.time()
    with _cache_lock:
        _cache = _CacheEntry(payload=payload, expires_at=now + max(1.0, ttl_sec))
    return payload


def _safe(probe, name: str) -> dict:
    try:
        return probe()
    except Exception as exc:  # noqa: BLE001 — probe failure must not crash engine
        logger.warning("hardware probe '%s' failed: %s", name, exc)
        return {
            "status": STATUS_UNKNOWN,
            "issues": [f"probe_failed: {exc}"],
            "metrics": {},
            "items": [],
        }


def reset_cache_for_tests() -> None:
    """Test helper — drop the TTL cache."""
    global _cache
    with _cache_lock:
        _cache = None


__all__ = [
    "STATUS_CRITICAL",
    "STATUS_HEALTHY",
    "STATUS_UNKNOWN",
    "STATUS_WARNING",
    "collect_health",
    "collect_component",
    "reset_cache_for_tests",
    "worst_status",
]
