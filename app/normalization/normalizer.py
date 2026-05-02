"""
SentraCore — Data Normalization Layer.

Processes raw SystemSnapshots into NormalizedSnapshots suitable for
analysis by downstream engines. Handles:

- Exponential Moving Average (EMA) smoothing for CPU, memory, disk
- Delta computation for cumulative disk I/O counters → rates (bytes/sec, ops/sec)
- Interval normalization for irregular sampling
- Spike noise filtering (requires consecutive elevated readings)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.collector.system_collector import SystemSnapshot
from app.config import EMA_ALPHA, MIN_SPIKE_READINGS

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class NormalizedSnapshot:
    """
    Processed telemetry data ready for analysis.

    All rate fields are per-second values derived from cumulative counters.
    Smoothed fields use EMA to reduce noise.
    """

    timestamp: float

    # Smoothed metrics
    cpu_percent_smoothed: float
    memory_percent_smoothed: float

    # Raw metrics (passed through for reference)
    cpu_percent_raw: float
    memory_percent_raw: float
    memory_used: int
    memory_available: int
    memory_total: int
    swap_percent: float

    # Disk I/O rates (computed from cumulative counter deltas)
    disk_read_bytes_per_sec: float
    disk_write_bytes_per_sec: float
    disk_read_ops_per_sec: float
    disk_write_ops_per_sec: float
    disk_total_bytes_per_sec: float
    disk_total_ops_per_sec: float

    # Spike detection
    cpu_is_spiking: bool
    memory_is_spiking: bool
    disk_is_spiking: bool

    def to_dict(self) -> dict:
        """Serialize for API output."""
        return {
            "timestamp": self.timestamp,
            "cpu": {
                "raw": round(self.cpu_percent_raw, 2),
                "smoothed": round(self.cpu_percent_smoothed, 2),
                "spiking": self.cpu_is_spiking,
            },
            "memory": {
                "raw": round(self.memory_percent_raw, 2),
                "smoothed": round(self.memory_percent_smoothed, 2),
                "used": self.memory_used,
                "available": self.memory_available,
                "total": self.memory_total,
                "spiking": self.memory_is_spiking,
            },
            "swap_percent": round(self.swap_percent, 2),
            "disk_io": {
                "read_bytes_per_sec": round(self.disk_read_bytes_per_sec, 2),
                "write_bytes_per_sec": round(self.disk_write_bytes_per_sec, 2),
                "read_ops_per_sec": round(self.disk_read_ops_per_sec, 2),
                "write_ops_per_sec": round(self.disk_write_ops_per_sec, 2),
                "total_bytes_per_sec": round(self.disk_total_bytes_per_sec, 2),
                "total_ops_per_sec": round(self.disk_total_ops_per_sec, 2),
                "spiking": self.disk_is_spiking,
            },
        }


class Normalizer:
    """
    Transforms raw SystemSnapshots into NormalizedSnapshots.

    Maintains internal state for EMA computation and delta tracking.
    Must be called sequentially with chronologically ordered snapshots.
    """

    def __init__(self, alpha: float = EMA_ALPHA, min_spike_readings: int = MIN_SPIKE_READINGS) -> None:
        self._alpha = alpha
        self._min_spike_readings = min_spike_readings

        # EMA state
        self._ema_cpu: float | None = None
        self._ema_memory: float | None = None

        # Previous snapshot for delta computation
        self._prev_timestamp: float | None = None
        self._prev_disk_read_bytes: int | None = None
        self._prev_disk_write_bytes: int | None = None
        self._prev_disk_read_count: int | None = None
        self._prev_disk_write_count: int | None = None

        # Consecutive spike counters for noise filtering
        self._cpu_spike_count: int = 0
        self._memory_spike_count: int = 0
        self._disk_spike_count: int = 0

        # Thresholds for spike detection (can be calibrated from baseline later)
        self._cpu_spike_threshold: float = 80.0
        self._memory_spike_threshold: float = 80.0
        self._disk_ops_spike_threshold: float = 400.0

    def normalize(self, snapshot: SystemSnapshot) -> NormalizedSnapshot:
        """
        Process a raw snapshot into a normalized snapshot.

        On the first call, EMA is initialized to the raw value and disk
        rates are zero (no prior delta reference).

        Args:
            snapshot: Raw system telemetry snapshot.

        Returns:
            NormalizedSnapshot with smoothed values and computed rates.
        """
        # ----- EMA Smoothing -----
        cpu_smoothed = self._update_ema("cpu", snapshot.cpu_percent)
        mem_smoothed = self._update_ema("memory", snapshot.memory_percent)

        # ----- Disk I/O Delta → Rates -----
        disk_rates = self._compute_disk_rates(snapshot)

        # ----- Spike Detection (consecutive readings filter) -----
        cpu_spiking = self._update_spike_counter(
            "cpu", snapshot.cpu_percent, self._cpu_spike_threshold
        )
        mem_spiking = self._update_spike_counter(
            "memory", snapshot.memory_percent, self._memory_spike_threshold
        )
        disk_spiking = self._update_spike_counter(
            "disk", disk_rates["total_ops_per_sec"], self._disk_ops_spike_threshold
        )

        # Store previous state for next delta
        self._prev_timestamp = snapshot.timestamp
        self._prev_disk_read_bytes = snapshot.disk_read_bytes
        self._prev_disk_write_bytes = snapshot.disk_write_bytes
        self._prev_disk_read_count = snapshot.disk_read_count
        self._prev_disk_write_count = snapshot.disk_write_count

        return NormalizedSnapshot(
            timestamp=snapshot.timestamp,
            cpu_percent_smoothed=cpu_smoothed,
            memory_percent_smoothed=mem_smoothed,
            cpu_percent_raw=snapshot.cpu_percent,
            memory_percent_raw=snapshot.memory_percent,
            memory_used=snapshot.memory_used,
            memory_available=snapshot.memory_available,
            memory_total=snapshot.memory_total,
            swap_percent=snapshot.swap_percent,
            disk_read_bytes_per_sec=disk_rates["read_bytes_per_sec"],
            disk_write_bytes_per_sec=disk_rates["write_bytes_per_sec"],
            disk_read_ops_per_sec=disk_rates["read_ops_per_sec"],
            disk_write_ops_per_sec=disk_rates["write_ops_per_sec"],
            disk_total_bytes_per_sec=disk_rates["total_bytes_per_sec"],
            disk_total_ops_per_sec=disk_rates["total_ops_per_sec"],
            cpu_is_spiking=cpu_spiking,
            memory_is_spiking=mem_spiking,
            disk_is_spiking=disk_spiking,
        )

    def _update_ema(self, metric: str, raw_value: float) -> float:
        """
        Update Exponential Moving Average for a metric.

        EMA formula: EMA_t = α × value_t + (1 - α) × EMA_{t-1}
        """
        if metric == "cpu":
            if self._ema_cpu is None:
                self._ema_cpu = raw_value
            else:
                self._ema_cpu = self._alpha * raw_value + (1 - self._alpha) * self._ema_cpu
            return self._ema_cpu
        elif metric == "memory":
            if self._ema_memory is None:
                self._ema_memory = raw_value
            else:
                self._ema_memory = self._alpha * raw_value + (1 - self._alpha) * self._ema_memory
            return self._ema_memory
        else:
            raise ValueError(f"Unknown EMA metric: {metric}")

    def _compute_disk_rates(self, snapshot: SystemSnapshot) -> dict[str, float]:
        """
        Compute disk I/O rates from cumulative counter deltas.

        Returns zero rates on the first call (no prior reference point).
        Handles counter wraps and irregular intervals gracefully.
        """
        if self._prev_timestamp is None or self._prev_disk_read_bytes is None:
            return {
                "read_bytes_per_sec": 0.0,
                "write_bytes_per_sec": 0.0,
                "read_ops_per_sec": 0.0,
                "write_ops_per_sec": 0.0,
                "total_bytes_per_sec": 0.0,
                "total_ops_per_sec": 0.0,
            }

        elapsed = snapshot.timestamp - self._prev_timestamp
        if elapsed <= 0:
            elapsed = 1.0  # Avoid division by zero

        # Compute deltas (handle counter wraps by clamping to zero)
        read_bytes_delta = max(0, snapshot.disk_read_bytes - self._prev_disk_read_bytes)
        write_bytes_delta = max(0, snapshot.disk_write_bytes - self._prev_disk_write_bytes)
        read_count_delta = max(0, snapshot.disk_read_count - self._prev_disk_read_count)
        write_count_delta = max(0, snapshot.disk_write_count - self._prev_disk_write_count)

        read_bps = read_bytes_delta / elapsed
        write_bps = write_bytes_delta / elapsed
        read_ops = read_count_delta / elapsed
        write_ops = write_count_delta / elapsed

        return {
            "read_bytes_per_sec": read_bps,
            "write_bytes_per_sec": write_bps,
            "read_ops_per_sec": read_ops,
            "write_ops_per_sec": write_ops,
            "total_bytes_per_sec": read_bps + write_bps,
            "total_ops_per_sec": read_ops + write_ops,
        }

    def _update_spike_counter(self, metric: str, value: float, threshold: float) -> bool:
        """
        Track consecutive elevated readings for spike noise filtering.

        A spike is only confirmed if the value exceeds the threshold for
        at least `min_spike_readings` consecutive samples.
        """
        if metric == "cpu":
            if value >= threshold:
                self._cpu_spike_count += 1
            else:
                self._cpu_spike_count = 0
            return self._cpu_spike_count >= self._min_spike_readings
        elif metric == "memory":
            if value >= threshold:
                self._memory_spike_count += 1
            else:
                self._memory_spike_count = 0
            return self._memory_spike_count >= self._min_spike_readings
        elif metric == "disk":
            if value >= threshold:
                self._disk_spike_count += 1
            else:
                self._disk_spike_count = 0
            return self._disk_spike_count >= self._min_spike_readings
        else:
            raise ValueError(f"Unknown spike metric: {metric}")

    def reset(self) -> None:
        """Reset all internal state. Useful for testing or recalibration."""
        self._ema_cpu = None
        self._ema_memory = None
        self._prev_timestamp = None
        self._prev_disk_read_bytes = None
        self._prev_disk_write_bytes = None
        self._prev_disk_read_count = None
        self._prev_disk_write_count = None
        self._cpu_spike_count = 0
        self._memory_spike_count = 0
        self._disk_spike_count = 0
