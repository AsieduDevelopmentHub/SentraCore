"""
SentraCore — Trend Analysis Engine.

Analyzes short-term buffers to detect growing pressures (slopes)
and measures system volatility. Used for early warning and predictive stress.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from engine.buffer.time_series_buffer import TimeSeriesBuffer

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class TrendResult:
    """Result of trend analysis over a time window."""

    cpu_slope: float           # % change per second
    memory_slope: float        # % change per second
    cpu_volatility: float      # Standard deviation of recent CPU values
    memory_volatility: float   # Standard deviation of recent memory values

    @property
    def is_cpu_growing(self) -> bool:
        """True if CPU is steadily growing at a concerning rate (>0.5% per sec)."""
        return self.cpu_slope > 0.5

    @property
    def is_memory_leaking(self) -> bool:
        """True if Memory is steadily growing at a concerning rate (>0.1% per sec)."""
        return self.memory_slope > 0.1

    def to_dict(self) -> dict:
        return {
            "cpu_slope": round(self.cpu_slope, 4),
            "memory_slope": round(self.memory_slope, 4),
            "cpu_volatility": round(self.cpu_volatility, 4),
            "memory_volatility": round(self.memory_volatility, 4),
            "is_cpu_growing": self.is_cpu_growing,
            "is_memory_leaking": self.is_memory_leaking,
        }


class TrendAnalyzer:
    """
    Computes linear regression and volatility on short-term telemetry data.
    """

    def __init__(self, window_size_samples: int = 30) -> None:
        """
        Args:
            window_size_samples: Number of recent samples to analyze. Default 30 samples (~60 seconds).
        """
        self._window_size = window_size_samples

    def analyze(self, buffer: TimeSeriesBuffer) -> TrendResult:
        """Analyze trends from the short-term buffer."""
        # Get recent CPU and Memory data
        cpu_data = buffer.get_recent_field("cpu_percent_smoothed", self._window_size)
        mem_data = buffer.get_recent_field("memory_percent_smoothed", self._window_size)
        timestamps = buffer.get_recent_field("timestamp", self._window_size)

        if len(timestamps) < 2:
            return TrendResult(0.0, 0.0, 0.0, 0.0)

        cpu_slope = self._calculate_slope(timestamps, cpu_data)
        mem_slope = self._calculate_slope(timestamps, mem_data)
        
        cpu_vol = self._calculate_volatility(cpu_data)
        mem_vol = self._calculate_volatility(mem_data)

        return TrendResult(
            cpu_slope=cpu_slope,
            memory_slope=mem_slope,
            cpu_volatility=cpu_vol,
            memory_volatility=mem_vol,
        )

    def _calculate_slope(self, x: list[float], y: list[float]) -> float:
        """Calculate linear regression slope."""
        if not x or not y or len(x) != len(y) or len(x) < 2:
            return 0.0

        n = len(x)
        # Normalize x to start at 0 to avoid huge floating point issues
        x_start = x[0]
        x_norm = [xi - x_start for xi in x]

        sum_x = sum(x_norm)
        sum_y = sum(y)
        sum_x_sq = sum(xi * xi for xi in x_norm)
        sum_xy = sum(x_norm[i] * y[i] for i in range(n))

        denominator = (n * sum_x_sq - sum_x * sum_x)
        if denominator == 0:
            return 0.0

        slope = (n * sum_xy - sum_x * sum_y) / denominator
        return slope

    def _calculate_volatility(self, data: list[float]) -> float:
        """Calculate standard deviation as a measure of volatility."""
        if not data or len(data) < 2:
            return 0.0

        mean = sum(data) / len(data)
        variance = sum((xi - mean) ** 2 for xi in data) / (len(data) - 1)
        import math
        return math.sqrt(variance)
