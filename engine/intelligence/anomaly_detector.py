"""
SentraCore — Anomaly Detection Engine.

Detects statistical deviations (z-scores) from the learned baseline.
Outputs continuous anomaly states rather than binary alerts.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from engine.baseline.baseline_model import BaselineModel
from engine.normalization.normalizer import NormalizedSnapshot

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class AnomalyResult:
    """Result of anomaly detection."""

    score: float  # Overall anomaly score (0-100)
    level: str  # "normal", "elevated", "high", "severe"
    cpu_z_score: float
    memory_z_score: float
    disk_z_score: float
    is_sustained: bool  # True if anomaly has persisted for several cycles

    def to_dict(self) -> dict:
        return {
            "score": round(self.score, 2),
            "level": self.level,
            "z_scores": {
                "cpu": round(self.cpu_z_score, 2),
                "memory": round(self.memory_z_score, 2),
                "disk": round(self.disk_z_score, 2),
            },
            "is_sustained": self.is_sustained,
        }


class AnomalyDetector:
    """
    Computes anomaly scores based on statistical deviation from baseline.
    Tracks sustained abnormalities to reduce noise.
    """

    def __init__(self, sustained_threshold_cycles: int = 5) -> None:
        self._sustained_threshold_cycles = sustained_threshold_cycles
        self._consecutive_anomaly_count = 0

    def detect(
        self,
        normalized: NormalizedSnapshot,
        baseline: BaselineModel,
        *,
        level_thresholds: tuple[float, float, float] | None = None,
    ) -> AnomalyResult:
        """
        Detect anomalies using current snapshot and active baseline.
        """
        if not baseline.is_ready:
            return AnomalyResult(0.0, "normal", 0.0, 0.0, 0.0, False)

        segment = baseline._get_segment_name(normalized.timestamp)

        cpu_z = self._calculate_z_score(
            normalized.cpu_percent_smoothed, baseline, "cpu_percent", segment
        )
        mem_z = self._calculate_z_score(
            normalized.memory_percent_smoothed, baseline, "memory_percent", segment
        )
        disk_z = self._calculate_z_score(
            normalized.disk_total_ops_per_sec, baseline, "disk_ops_per_sec", segment
        )

        # Max deviation is the primary driver of the anomaly score
        max_z = max(cpu_z, mem_z, disk_z)

        # Convert z-score to an anomaly score 0-100
        # z=0 -> 0 score. z=2 -> 40 score. z=3 -> 70 score. z>=4 -> 100 score.
        score = 0.0
        if max_z > 1.0:
            # Map [1.0, 4.0] to [0, 100]
            score = min(100.0, (max_z - 1.0) * (100.0 / 3.0))

        # Check sustained
        if score > 50.0:  # e.g., z > 2.5
            self._consecutive_anomaly_count += 1
        else:
            self._consecutive_anomaly_count = max(
                0, self._consecutive_anomaly_count - 1
            )

        is_sustained = (
            self._consecutive_anomaly_count >= self._sustained_threshold_cycles
        )

        t_elevated, t_high, t_severe = level_thresholds or (30.0, 60.0, 85.0)

        # Level (bands from user preference anomaly_sensitivity)
        if score < t_elevated:
            level = "normal"
        elif score < t_high:
            level = "elevated"
        elif score < t_severe:
            level = "high"
        else:
            level = "severe"

        return AnomalyResult(
            score=score,
            level=level,
            cpu_z_score=cpu_z,
            memory_z_score=mem_z,
            disk_z_score=disk_z,
            is_sustained=is_sustained,
        )

    def _calculate_z_score(
        self, value: float, baseline: BaselineModel, metric: str, segment: str
    ) -> float:
        """Calculate Z-score for a given value, metric, and segment."""
        # Need to access internal stats. We'll use the private method for now.
        stats = baseline._get_metric_stats(metric, segment)
        if stats is None or stats.count < baseline._min_samples:
            stats = baseline._get_metric_stats(metric, "global")

        if stats is None or stats.count < baseline._min_samples:
            return 0.0

        if stats.std_dev == 0:
            return (
                0.0 if value <= stats.mean else 3.0
            )  # Arbitrary high z-score if deviated from strict flatline

        # Only consider positive deviations (higher than normal) as anomalous for stress
        if value <= stats.mean:
            return 0.0

        return (value - stats.mean) / stats.std_dev
