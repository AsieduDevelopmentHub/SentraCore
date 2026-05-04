"""
SentraCore — Process Intelligence Tracker.

Tracks sustained per-process resource impact over a sliding window,
rather than relying on single-snapshot rankings. Processes are ranked
by their average impact over time, providing a more accurate picture
of which processes are actually stressing the system.
"""

from __future__ import annotations

import logging
from collections import deque
from dataclasses import dataclass

from engine.collector.system_collector import ProcessInfo
from engine.config import (
    PROCESS_MISS_SNAPSHOTS_BEFORE_PRUNE,
    PROCESS_WINDOW_SIZE,
    TOP_PROCESSES_COUNT,
)

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class ProcessImpact:
    """Sustained impact assessment for a single process."""

    pid: int
    name: str
    avg_cpu_percent: float
    avg_memory_percent: float
    peak_cpu_percent: float
    peak_memory_percent: float
    current_cpu_percent: float
    current_memory_percent: float
    sample_count: int
    impact_score: float  # Combined sustained impact metric

    def to_dict(self) -> dict:
        """Serialize for API output."""
        return {
            "pid": self.pid,
            "name": self.name,
            "avg_cpu_percent": round(self.avg_cpu_percent, 2),
            "avg_memory_percent": round(self.avg_memory_percent, 2),
            "peak_cpu_percent": round(self.peak_cpu_percent, 2),
            "peak_memory_percent": round(self.peak_memory_percent, 2),
            "current_cpu_percent": round(self.current_cpu_percent, 2),
            "current_memory_percent": round(self.current_memory_percent, 2),
            "sample_count": self.sample_count,
            "impact_score": round(self.impact_score, 2),
        }


@dataclass
class _ProcessWindow:
    """Internal sliding window data for a tracked process."""

    name: str
    cpu_history: deque[float]
    mem_history: deque[float]
    last_seen_cpu: float = 0.0
    last_seen_mem: float = 0.0
    miss_snapshots: int = 0

    def __init__(self, name: str, window_size: int) -> None:
        self.name = name
        self.cpu_history = deque(maxlen=window_size)
        self.mem_history = deque(maxlen=window_size)

    def push(self, cpu: float, mem: float) -> None:
        self.cpu_history.append(cpu)
        self.mem_history.append(mem)
        self.last_seen_cpu = cpu
        self.last_seen_mem = mem


class ProcessTracker:
    """
    Tracks per-process resource usage over a sliding window.

    Maintains a history buffer per process ID and computes sustained
    impact scores based on average resource usage over the window.
    Handles process churn (appear/disappear) gracefully.
    """

    def __init__(
        self,
        window_size: int = PROCESS_WINDOW_SIZE,
        top_count: int = TOP_PROCESSES_COUNT,
        miss_prune_snapshots: int = PROCESS_MISS_SNAPSHOTS_BEFORE_PRUNE,
    ) -> None:
        self._window_size = window_size
        self._top_count = top_count
        self._miss_prune_snapshots = max(1, int(miss_prune_snapshots))
        self._tracked: dict[int, _ProcessWindow] = {}
        self._active_pids: set[int] = set()

    def update(self, processes: tuple[ProcessInfo, ...] | list[ProcessInfo]) -> None:
        """
        Update tracking with a new set of process snapshots.

        New processes are added to tracking. Processes not seen in the
        current snapshot are left in history but marked inactive.
        """
        current_pids: set[int] = set()

        for proc in processes:
            current_pids.add(proc.pid)

            if proc.pid not in self._tracked:
                self._tracked[proc.pid] = _ProcessWindow(
                    name=proc.name,
                    window_size=self._window_size,
                )

            window = self._tracked[proc.pid]
            window.name = proc.name  # Update name in case it changed
            window.push(proc.cpu_percent, proc.memory_percent)

        self._active_pids = current_pids

        for pid, window in self._tracked.items():
            if pid in current_pids:
                window.miss_snapshots = 0
            else:
                window.miss_snapshots += 1

        for pid in list(self._tracked):
            if self._tracked[pid].miss_snapshots >= self._miss_prune_snapshots:
                del self._tracked[pid]

    def get_top_consumers(self, n: int | None = None) -> list[ProcessImpact]:
        """
        Return top N processes ranked by sustained impact score.

        Impact score = weighted combination of average CPU and memory
        usage over the sliding window, with a recency bonus.

        Args:
            n: Number of top processes to return. Defaults to configured count.
        """
        if n is None:
            n = self._top_count

        impacts: list[ProcessImpact] = []

        for pid, window in self._tracked.items():
            if not window.cpu_history:
                continue

            cpu_values = list(window.cpu_history)
            mem_values = list(window.mem_history)

            avg_cpu = sum(cpu_values) / len(cpu_values)
            avg_mem = sum(mem_values) / len(mem_values)
            peak_cpu = max(cpu_values)
            peak_mem = max(mem_values)

            # Impact score: weighted average of CPU and memory, favoring sustained usage
            # CPU gets slightly more weight as it directly affects responsiveness
            impact_score = avg_cpu * 0.6 + avg_mem * 0.4

            impacts.append(
                ProcessImpact(
                    pid=pid,
                    name=window.name,
                    avg_cpu_percent=avg_cpu,
                    avg_memory_percent=avg_mem,
                    peak_cpu_percent=peak_cpu,
                    peak_memory_percent=peak_mem,
                    current_cpu_percent=window.last_seen_cpu,
                    current_memory_percent=window.last_seen_mem,
                    sample_count=len(cpu_values),
                    impact_score=impact_score,
                )
            )

        # Sort by impact score descending
        impacts.sort(key=lambda p: p.impact_score, reverse=True)
        return impacts[:n]

    def get_active_count(self) -> int:
        """Number of currently active (recently seen) processes."""
        return len(self._active_pids)

    def reset(self) -> None:
        """Clear all tracking data."""
        self._tracked.clear()
        self._active_pids.clear()
