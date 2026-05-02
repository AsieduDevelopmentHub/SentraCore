"""
SentraCore — Dual Time-Series Buffer.

Maintains two ring buffers (short-window and long-window) for system
telemetry snapshots. The short window captures real-time behavior
(~5 minutes) while the long window captures behavioral trends (~60 minutes).

Thread-safe via a reentrant lock to support concurrent reads from the
API layer while the collection loop writes.
"""

from __future__ import annotations

import threading
from collections import deque
from typing import Any

from app.collector.system_collector import SystemSnapshot
from app.config import LONG_BUFFER_SIZE, SHORT_BUFFER_SIZE


class TimeSeriesBuffer:
    """
    Dual ring buffer for system telemetry time-series data.

    Attributes:
        short_window: Recent snapshots for real-time analysis.
        long_window: Extended history for trend and baseline analysis.
    """

    def __init__(
        self,
        short_size: int = SHORT_BUFFER_SIZE,
        long_size: int = LONG_BUFFER_SIZE,
    ) -> None:
        self._short: deque[SystemSnapshot] = deque(maxlen=short_size)
        self._long: deque[SystemSnapshot] = deque(maxlen=long_size)
        self._lock = threading.RLock()

    # ----- Write Operations -----

    def push(self, snapshot: SystemSnapshot) -> None:
        """
        Append a snapshot to both short and long buffers.

        Old entries are automatically evicted when buffers reach capacity.
        """
        with self._lock:
            self._short.append(snapshot)
            self._long.append(snapshot)

    # ----- Read Operations (Short Window) -----

    def get_short_window(self) -> list[SystemSnapshot]:
        """Return all snapshots in the short-term buffer (copy)."""
        with self._lock:
            return list(self._short)

    def get_short_window_field(self, field: str) -> list[Any]:
        """
        Extract a single field from all short-window snapshots.

        Args:
            field: Attribute name on SystemSnapshot (e.g., 'cpu_percent').

        Returns:
            List of field values in chronological order.

        Raises:
            AttributeError: If the field does not exist on SystemSnapshot.
        """
        with self._lock:
            return [getattr(s, field) for s in self._short]

    # ----- Read Operations (Long Window) -----

    def get_long_window(self) -> list[SystemSnapshot]:
        """Return all snapshots in the long-term buffer (copy)."""
        with self._lock:
            return list(self._long)

    def get_long_window_field(self, field: str) -> list[Any]:
        """
        Extract a single field from all long-window snapshots.

        Args:
            field: Attribute name on SystemSnapshot (e.g., 'memory_percent').

        Returns:
            List of field values in chronological order.
        """
        with self._lock:
            return [getattr(s, field) for s in self._long]

    # ----- Metadata -----

    @property
    def short_count(self) -> int:
        """Number of snapshots currently in the short buffer."""
        with self._lock:
            return len(self._short)

    @property
    def long_count(self) -> int:
        """Number of snapshots currently in the long buffer."""
        with self._lock:
            return len(self._long)

    @property
    def short_capacity(self) -> int:
        """Maximum capacity of the short buffer."""
        return self._short.maxlen or 0

    @property
    def long_capacity(self) -> int:
        """Maximum capacity of the long buffer."""
        return self._long.maxlen or 0

    def get_latest(self) -> SystemSnapshot | None:
        """Return the most recent snapshot, or None if empty."""
        with self._lock:
            return self._short[-1] if self._short else None

    def clear(self) -> None:
        """Clear both buffers."""
        with self._lock:
            self._short.clear()
            self._long.clear()
