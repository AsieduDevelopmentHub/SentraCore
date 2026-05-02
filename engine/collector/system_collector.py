"""
SentraCore — System Telemetry Collector.

Collects real-time system telemetry snapshots using psutil.
Each snapshot captures CPU, memory, disk, and per-process resource usage
at a single point in time. The collector is designed for non-blocking,
low-overhead operation suitable for continuous monitoring loops.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field

import psutil

from engine.config import MAX_PROCESSES_PER_SNAPSHOT

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class ProcessInfo:
    """Snapshot of a single process's resource usage."""

    pid: int
    name: str
    cpu_percent: float
    memory_percent: float
    memory_rss: int  # Resident Set Size in bytes
    status: str
    create_time: float

    def to_dict(self) -> dict:
        """Serialize to dictionary for API/storage."""
        return {
            "pid": self.pid,
            "name": self.name,
            "cpu_percent": round(self.cpu_percent, 2),
            "memory_percent": round(self.memory_percent, 2),
            "memory_rss": self.memory_rss,
            "status": self.status,
            "create_time": self.create_time,
        }


@dataclass(frozen=True, slots=True)
class SystemSnapshot:
    """
    Complete system telemetry snapshot at a single point in time.

    Contains CPU, memory, swap, disk I/O counters, and a list of
    the top processes ranked by combined CPU + memory usage.
    """

    timestamp: float

    # CPU metrics
    cpu_percent: float
    cpu_per_core: tuple[float, ...]
    cpu_count_logical: int

    # Memory metrics
    memory_total: int
    memory_used: int
    memory_available: int
    memory_percent: float

    # Swap metrics
    swap_total: int
    swap_used: int
    swap_percent: float

    # Disk I/O counters (cumulative — delta computed by normalizer)
    disk_read_bytes: int
    disk_write_bytes: int
    disk_read_count: int
    disk_write_count: int

    # Top processes by resource impact
    processes: tuple[ProcessInfo, ...] = field(default_factory=tuple)

    def to_dict(self) -> dict:
        """Serialize to dictionary for API/WebSocket broadcast."""
        return {
            "timestamp": self.timestamp,
            "cpu": {
                "percent": round(self.cpu_percent, 2),
                "per_core": [round(c, 2) for c in self.cpu_per_core],
                "logical_count": self.cpu_count_logical,
            },
            "memory": {
                "total": self.memory_total,
                "used": self.memory_used,
                "available": self.memory_available,
                "percent": round(self.memory_percent, 2),
            },
            "swap": {
                "total": self.swap_total,
                "used": self.swap_used,
                "percent": round(self.swap_percent, 2),
            },
            "disk_io": {
                "read_bytes": self.disk_read_bytes,
                "write_bytes": self.disk_write_bytes,
                "read_count": self.disk_read_count,
                "write_count": self.disk_write_count,
            },
            "processes": [p.to_dict() for p in self.processes],
        }


class SystemCollector:
    """
    Collects system telemetry snapshots using psutil.

    Usage::

        collector = SystemCollector()
        collector.prime()  # Initial CPU measurement baseline
        snapshot = collector.collect()
    """

    def __init__(self, max_processes: int = MAX_PROCESSES_PER_SNAPSHOT) -> None:
        self._max_processes = max_processes
        self._cpu_count = psutil.cpu_count(logical=True) or 1
        self._primed = False

    def prime(self) -> None:
        """
        Prime the CPU percent measurement.

        psutil.cpu_percent() requires a prior call to establish a delta
        baseline. Call this once before the main collection loop starts.
        """
        psutil.cpu_percent(interval=None, percpu=True)
        self._primed = True
        logger.debug("SystemCollector primed for CPU delta measurement.")

    def collect(self) -> SystemSnapshot:
        """
        Collect a complete system telemetry snapshot.

        Returns:
            SystemSnapshot with current CPU, memory, disk, and process data.

        Raises:
            RuntimeError: If collect() is called before prime().
        """
        if not self._primed:
            raise RuntimeError(
                "SystemCollector.prime() must be called before collect(). "
                "The first cpu_percent() call establishes the measurement baseline."
            )

        timestamp = time.time()

        # ----- CPU -----
        cpu_per_core = psutil.cpu_percent(interval=None, percpu=True)
        cpu_percent = sum(cpu_per_core) / len(cpu_per_core) if cpu_per_core else 0.0

        # ----- Memory -----
        mem = psutil.virtual_memory()

        # ----- Swap -----
        swap = psutil.swap_memory()

        # ----- Disk I/O -----
        try:
            disk_io = psutil.disk_io_counters()
            if disk_io is None:
                disk_read_bytes = disk_write_bytes = 0
                disk_read_count = disk_write_count = 0
            else:
                disk_read_bytes = disk_io.read_bytes
                disk_write_bytes = disk_io.write_bytes
                disk_read_count = disk_io.read_count
                disk_write_count = disk_io.write_count
        except RuntimeError:
            # disk_io_counters() can fail on some systems
            disk_read_bytes = disk_write_bytes = 0
            disk_read_count = disk_write_count = 0
            logger.warning("Disk I/O counters unavailable on this system.")

        # ----- Processes -----
        processes = self._collect_processes()

        return SystemSnapshot(
            timestamp=timestamp,
            cpu_percent=cpu_percent,
            cpu_per_core=tuple(cpu_per_core),
            cpu_count_logical=self._cpu_count,
            memory_total=mem.total,
            memory_used=mem.used,
            memory_available=mem.available,
            memory_percent=mem.percent,
            swap_total=swap.total,
            swap_used=swap.used,
            swap_percent=swap.percent,
            disk_read_bytes=disk_read_bytes,
            disk_write_bytes=disk_write_bytes,
            disk_read_count=disk_read_count,
            disk_write_count=disk_write_count,
            processes=tuple(processes),
        )

    def _collect_processes(self) -> list[ProcessInfo]:
        """
        Collect top processes ranked by combined CPU + memory impact.

        Handles AccessDenied and NoSuchProcess gracefully — processes that
        cannot be read are silently skipped.
        """
        proc_list: list[ProcessInfo] = []

        for proc in psutil.process_iter(
            attrs=["pid", "name", "cpu_percent", "memory_percent", "memory_info", "status", "create_time"]
        ):
            try:
                info = proc.info
                proc_list.append(
                    ProcessInfo(
                        pid=info["pid"],
                        name=info["name"] or "Unknown",
                        cpu_percent=info.get("cpu_percent") or 0.0,
                        memory_percent=info.get("memory_percent") or 0.0,
                        memory_rss=(info.get("memory_info") or type("", (), {"rss": 0})()).rss,
                        status=info.get("status") or "unknown",
                        create_time=info.get("create_time") or 0.0,
                    )
                )
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
            except Exception as exc:
                logger.debug("Skipping process due to error: %s", exc)
                continue

        # Rank by combined CPU + memory impact, take top N
        proc_list.sort(
            key=lambda p: p.cpu_percent + p.memory_percent,
            reverse=True,
        )
        return proc_list[: self._max_processes]
