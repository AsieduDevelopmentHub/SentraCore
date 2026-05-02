"""
SentraCore — Event Logger.

Captures and stores discrete system events (CPU spikes, memory pressure,
disk spikes, process start/stop) for future correlation analysis (Phase 3).
Events are stored in an in-memory ring buffer and also written to the
Python logging system.
"""

from __future__ import annotations

import logging
import time
from collections import deque
from dataclasses import dataclass, field

from app.collector.system_collector import SystemSnapshot
from app.config import (
    EVENT_CPU_SPIKE_THRESHOLD,
    EVENT_DISK_SPIKE_THRESHOLD,
    EVENT_MEMORY_PRESSURE_THRESHOLD,
    MAX_EVENTS,
)
from app.normalization.normalizer import NormalizedSnapshot

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class SystemEvent:
    """Discrete system event with context."""

    timestamp: float
    event_type: str   # "cpu_spike", "memory_pressure", "disk_spike", "process_start", "process_stop"
    severity: str     # "info", "warning", "critical"
    details: dict     # Context-specific data

    def to_dict(self) -> dict:
        return {
            "timestamp": self.timestamp,
            "event_type": self.event_type,
            "severity": self.severity,
            "details": self.details,
        }


class EventLogger:
    """
    Detects and logs system events by comparing telemetry against
    thresholds and tracking state transitions.

    Events are stored in a ring buffer (most recent N events) and
    emitted to Python logging for external consumption.
    """

    def __init__(
        self,
        max_events: int = MAX_EVENTS,
        cpu_threshold: float = EVENT_CPU_SPIKE_THRESHOLD,
        memory_threshold: float = EVENT_MEMORY_PRESSURE_THRESHOLD,
        disk_threshold: float = EVENT_DISK_SPIKE_THRESHOLD,
    ) -> None:
        self._buffer: deque[SystemEvent] = deque(maxlen=max_events)
        self._cpu_threshold = cpu_threshold
        self._memory_threshold = memory_threshold
        self._disk_threshold = disk_threshold

        # State tracking for edge detection (only fire on transition)
        self._cpu_spike_active = False
        self._memory_pressure_active = False
        self._disk_spike_active = False
        self._known_pids: set[int] = set()

    def analyze(
        self,
        snapshot: SystemSnapshot,
        normalized: NormalizedSnapshot,
    ) -> list[SystemEvent]:
        """
        Analyze a snapshot/normalized pair and emit any detected events.

        Returns the list of new events generated in this cycle.
        """
        new_events: list[SystemEvent] = []
        ts = snapshot.timestamp

        # ----- CPU Spike Detection -----
        if normalized.cpu_is_spiking and not self._cpu_spike_active:
            event = SystemEvent(
                timestamp=ts,
                event_type="cpu_spike",
                severity="warning",
                details={
                    "cpu_percent": round(normalized.cpu_percent_raw, 2),
                    "cpu_smoothed": round(normalized.cpu_percent_smoothed, 2),
                    "threshold": self._cpu_threshold,
                },
            )
            new_events.append(event)
            self._cpu_spike_active = True
            logger.warning("CPU spike detected: %.1f%%", normalized.cpu_percent_raw)

        elif not normalized.cpu_is_spiking and self._cpu_spike_active:
            event = SystemEvent(
                timestamp=ts,
                event_type="cpu_spike",
                severity="info",
                details={
                    "message": "CPU spike resolved",
                    "cpu_percent": round(normalized.cpu_percent_raw, 2),
                },
            )
            new_events.append(event)
            self._cpu_spike_active = False
            logger.info("CPU spike resolved: %.1f%%", normalized.cpu_percent_raw)

        # ----- Memory Pressure Detection -----
        if normalized.memory_is_spiking and not self._memory_pressure_active:
            event = SystemEvent(
                timestamp=ts,
                event_type="memory_pressure",
                severity="warning",
                details={
                    "memory_percent": round(normalized.memory_percent_raw, 2),
                    "memory_smoothed": round(normalized.memory_percent_smoothed, 2),
                    "memory_available": normalized.memory_available,
                    "threshold": self._memory_threshold,
                },
            )
            new_events.append(event)
            self._memory_pressure_active = True
            logger.warning("Memory pressure detected: %.1f%%", normalized.memory_percent_raw)

        elif not normalized.memory_is_spiking and self._memory_pressure_active:
            event = SystemEvent(
                timestamp=ts,
                event_type="memory_pressure",
                severity="info",
                details={
                    "message": "Memory pressure resolved",
                    "memory_percent": round(normalized.memory_percent_raw, 2),
                },
            )
            new_events.append(event)
            self._memory_pressure_active = False

        # ----- Disk Spike Detection -----
        if normalized.disk_is_spiking and not self._disk_spike_active:
            event = SystemEvent(
                timestamp=ts,
                event_type="disk_spike",
                severity="warning",
                details={
                    "disk_ops_per_sec": round(normalized.disk_total_ops_per_sec, 2),
                    "disk_bytes_per_sec": round(normalized.disk_total_bytes_per_sec, 2),
                    "threshold": self._disk_threshold,
                },
            )
            new_events.append(event)
            self._disk_spike_active = True
            logger.warning("Disk spike detected: %.1f ops/sec", normalized.disk_total_ops_per_sec)

        elif not normalized.disk_is_spiking and self._disk_spike_active:
            event = SystemEvent(
                timestamp=ts,
                event_type="disk_spike",
                severity="info",
                details={
                    "message": "Disk spike resolved",
                    "disk_ops_per_sec": round(normalized.disk_total_ops_per_sec, 2),
                },
            )
            new_events.append(event)
            self._disk_spike_active = False

        # ----- Process Start/Stop Detection -----
        current_pids = {p.pid for p in snapshot.processes}

        if self._known_pids:
            # New processes
            for pid in current_pids - self._known_pids:
                proc = next((p for p in snapshot.processes if p.pid == pid), None)
                if proc:
                    event = SystemEvent(
                        timestamp=ts,
                        event_type="process_start",
                        severity="info",
                        details={
                            "pid": proc.pid,
                            "name": proc.name,
                            "cpu_percent": round(proc.cpu_percent, 2),
                            "memory_percent": round(proc.memory_percent, 2),
                        },
                    )
                    new_events.append(event)

            # Stopped processes
            for pid in self._known_pids - current_pids:
                event = SystemEvent(
                    timestamp=ts,
                    event_type="process_stop",
                    severity="info",
                    details={"pid": pid},
                )
                new_events.append(event)

        self._known_pids = current_pids

        # Store events
        for event in new_events:
            self._buffer.append(event)

        return new_events

    def get_recent_events(self, n: int = 50) -> list[SystemEvent]:
        """Return the N most recent events (newest first)."""
        events = list(self._buffer)
        events.reverse()
        return events[:n]

    def get_all_events(self) -> list[SystemEvent]:
        """Return all stored events (oldest first)."""
        return list(self._buffer)

    @property
    def event_count(self) -> int:
        return len(self._buffer)

    def clear(self) -> None:
        """Clear all stored events and reset state."""
        self._buffer.clear()
        self._cpu_spike_active = False
        self._memory_pressure_active = False
        self._disk_spike_active = False
        self._known_pids.clear()
