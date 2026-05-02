"""
SentraCore — Prediction & Risk Engine.

Forecasts resource exhaustion and calculates degradation probability based
on smoothed historical trends.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from engine.intelligence.trend_analyzer import TrendResult
    from engine.normalization.normalizer import NormalizedSnapshot

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class PredictionResult:
    """Forecast of system degradation and resource exhaustion."""

    memory_exhaustion_eta_sec: float | None
    cpu_critical_eta_sec: float | None
    risk_score: float  # 0 to 100%

    def to_dict(self) -> dict:
        return {
            "memory_exhaustion_eta_sec": (
                round(self.memory_exhaustion_eta_sec, 1) if self.memory_exhaustion_eta_sec else None
            ),
            "cpu_critical_eta_sec": (
                round(self.cpu_critical_eta_sec, 1) if self.cpu_critical_eta_sec else None
            ),
            "risk_score": round(self.risk_score, 2),
        }


class PredictionEngine:
    """
    Computes Time-To-Exhaustion (TTE) for critical resources using
    smoothed trend slopes, and produces an overarching risk score.
    """

    def __init__(self, smoothing_factor: float = 0.2) -> None:
        """
        Args:
            smoothing_factor: Weight given to the new slope (EMA) to prevent chaotic ETAs.
        """
        self._smoothing_factor = smoothing_factor
        self._smoothed_cpu_slope = 0.0
        self._smoothed_memory_slope = 0.0

    def predict(self, trend: 'TrendResult', snapshot: 'NormalizedSnapshot') -> PredictionResult:
        """
        Forecast resource exhaustion.

        Args:
            trend: The current trend analysis (containing slopes).
            snapshot: Current normalized telemetry (for starting points).

        Returns:
            A PredictionResult indicating ETAs and overall risk.
        """
        # Apply Exponential Moving Average (EMA) to the slopes to smooth them
        if self._smoothed_cpu_slope == 0.0:
            self._smoothed_cpu_slope = trend.cpu_slope
        else:
            self._smoothed_cpu_slope = (
                self._smoothing_factor * trend.cpu_slope
                + (1 - self._smoothing_factor) * self._smoothed_cpu_slope
            )

        if self._smoothed_memory_slope == 0.0:
            self._smoothed_memory_slope = trend.memory_slope
        else:
            self._smoothed_memory_slope = (
                self._smoothing_factor * trend.memory_slope
                + (1 - self._smoothing_factor) * self._smoothed_memory_slope
            )

        # Calculate Memory ETA to 98%
        mem_eta = None
        if self._smoothed_memory_slope > 0.05:  # Require at least 0.05% growth per second to forecast
            remaining_mem = 98.0 - snapshot.memory_percent_smoothed
            if remaining_mem > 0:
                mem_eta = remaining_mem / self._smoothed_memory_slope

        # Calculate CPU ETA to 95%
        cpu_eta = None
        if self._smoothed_cpu_slope > 0.1:  # Require at least 0.1% growth per second to forecast
            remaining_cpu = 95.0 - snapshot.cpu_percent_smoothed
            if remaining_cpu > 0:
                cpu_eta = remaining_cpu / self._smoothed_cpu_slope

        # Calculate Probabilistic Risk Score (0-100)
        risk_score = 0.0
        
        # Risk from Memory exhaustion proximity
        if mem_eta is not None:
            if mem_eta < 60:
                risk_score += 80.0  # Under 1 minute to OOM is critical
            elif mem_eta < 300:
                risk_score += 40.0  # Under 5 minutes is high risk
            else:
                risk_score += 10.0  # Leaking, but slow
                
        # Risk from CPU exhaustion proximity
        if cpu_eta is not None:
            if cpu_eta < 30:
                risk_score += 60.0  # Fast spike to saturation
            elif cpu_eta < 120:
                risk_score += 30.0
                
        # Base risk based on sheer resource usage, regardless of slope
        if snapshot.memory_percent_smoothed > 90.0:
            risk_score += 40.0
        if snapshot.cpu_percent_smoothed > 90.0:
            risk_score += 30.0

        return PredictionResult(
            memory_exhaustion_eta_sec=mem_eta,
            cpu_critical_eta_sec=cpu_eta,
            risk_score=min(100.0, risk_score),
        )
