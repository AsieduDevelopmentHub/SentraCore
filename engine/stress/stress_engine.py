"""
SentraCore — Signal-Based Stress Engine.

Computes a System Stress Score (0–100) from normalized telemetry data
using signal-based scoring rather than static thresholds. The engine
analyzes CPU trend intensity, memory pressure ratio, and disk activity
rate to produce a weighted composite score.

Weights are adaptive: when one resource is clearly under heavy pressure
it receives increased weight in the final score.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from engine.intelligence.trend_analyzer import TrendResult
    from engine.intelligence.anomaly_detector import AnomalyResult

from engine.config import (
    STRESS_HIGH_THRESHOLD,
    STRESS_LOW_THRESHOLD,
    STRESS_MODERATE_THRESHOLD,
    STRESS_WEIGHT_CPU,
    STRESS_WEIGHT_DISK,
    STRESS_WEIGHT_MEMORY,
)
from engine.normalization.normalizer import NormalizedSnapshot

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class StressResult:
    """Result of stress score computation."""

    score: float  # 0–100
    level: str  # "low", "moderate", "high", "critical"
    cpu_pressure: float  # 0–100 CPU contribution
    memory_pressure: float  # 0–100 memory contribution
    disk_pressure: float  # 0–100 disk contribution
    weights: dict[str, float]  # Adaptive weights used

    def to_dict(self) -> dict:
        """Serialize for API output."""
        return {
            "score": round(self.score, 2),
            "level": self.level,
            "pressures": {
                "cpu": round(self.cpu_pressure, 2),
                "memory": round(self.memory_pressure, 2),
                "disk": round(self.disk_pressure, 2),
            },
            "weights": {k: round(v, 3) for k, v in self.weights.items()},
        }


class StressEngine:
    """
    Computes system stress from normalized telemetry signals.

    The engine uses three input signals:
    - CPU trend intensity (EMA-smoothed CPU percent)
    - Memory pressure ratio (used vs available, accounting for swap)
    - Disk activity rate (normalized ops/sec against a reference baseline)

    Weights adapt dynamically: if any single signal exceeds 80%, it gets
    a boost to reflect disproportionate system impact.
    """

    def __init__(
        self,
        weight_cpu: float = STRESS_WEIGHT_CPU,
        weight_memory: float = STRESS_WEIGHT_MEMORY,
        weight_disk: float = STRESS_WEIGHT_DISK,
    ) -> None:
        self._base_weight_cpu = weight_cpu
        self._base_weight_memory = weight_memory
        self._base_weight_disk = weight_disk

        # Reference disk ops/sec for normalization (calibrated from baseline later)
        self._disk_ops_reference: float = 500.0

    def compute(
        self,
        normalized: NormalizedSnapshot,
        trend: "TrendResult" = None,
        anomaly: "AnomalyResult" = None,
    ) -> StressResult:
        """
        Compute the system stress score from a normalized snapshot.
        Incorporates trend and anomaly data if provided (Phase 2 Multi-State).

        Args:
            normalized: Processed telemetry data.
            trend: Optional trend analysis result.
            anomaly: Optional anomaly detection result.

        Returns:
            StressResult with score, level, and per-resource pressures.
        """
        # ----- Compute Individual Pressures (0–100 each) -----

        cpu_pressure = self._compute_cpu_pressure(normalized)
        memory_pressure = self._compute_memory_pressure(normalized)
        disk_pressure = self._compute_disk_pressure(normalized)

        # ----- Incorporate Trend & Volatility (Multi-State Adjustments) -----

        if trend:
            # If CPU is steadily growing, increase CPU pressure
            if trend.is_cpu_growing:
                cpu_pressure = min(100.0, cpu_pressure + (trend.cpu_slope * 10))
            # If memory is leaking, increase memory pressure
            if trend.is_memory_leaking:
                memory_pressure = min(
                    100.0, memory_pressure + (trend.memory_slope * 20)
                )

        if anomaly and anomaly.is_sustained:
            # Sustained anomalies boost overall pressure implicitly by boosting components
            # based on their z-scores
            if anomaly.cpu_z_score > 2.0:
                cpu_pressure = min(100.0, cpu_pressure + 10.0)
            if anomaly.memory_z_score > 2.0:
                memory_pressure = min(100.0, memory_pressure + 10.0)

        # ----- Adaptive Weighting -----

        weights = self._adapt_weights(cpu_pressure, memory_pressure, disk_pressure)

        # ----- Weighted Composite Score -----

        raw_score = (
            weights["cpu"] * cpu_pressure
            + weights["memory"] * memory_pressure
            + weights["disk"] * disk_pressure
        )

        # Clamp to 0–100
        score = max(0.0, min(100.0, raw_score))

        # ----- Classify Level -----

        level = self._classify_level(score)

        return StressResult(
            score=score,
            level=level,
            cpu_pressure=cpu_pressure,
            memory_pressure=memory_pressure,
            disk_pressure=disk_pressure,
            weights=weights,
        )

    def set_disk_ops_reference(self, reference: float) -> None:
        """
        Set the reference disk ops/sec for normalization.

        Should be called when baseline data becomes available to calibrate
        disk pressure scoring against the machine's normal activity.
        """
        if reference > 0:
            self._disk_ops_reference = reference
            logger.info("Disk ops reference updated to %.1f ops/sec", reference)

    def _compute_cpu_pressure(self, normalized: NormalizedSnapshot) -> float:
        """
        Compute CPU pressure signal (0–100).

        Uses the EMA-smoothed CPU percent directly. The smoothing already
        filters out single-sample noise, so sustained high CPU = high pressure.
        """
        return min(100.0, normalized.cpu_percent_smoothed)

    def _compute_memory_pressure(self, normalized: NormalizedSnapshot) -> float:
        """
        Compute memory pressure signal (0–100).

        Uses a pressure ratio that accounts for available memory rather than
        simple used/total. Systems with high memory usage but sufficient
        available memory (due to caching) should score lower.

        Swap usage adds additional pressure.
        """
        if normalized.memory_total == 0:
            return 0.0

        # Available memory ratio (lower available = higher pressure)
        available_ratio = normalized.memory_available / normalized.memory_total
        memory_score = (1.0 - available_ratio) * 100.0

        # Swap penalty: add pressure if swap is being used
        swap_penalty = min(20.0, normalized.swap_percent * 0.4)

        return min(100.0, memory_score + swap_penalty)

    def _compute_disk_pressure(self, normalized: NormalizedSnapshot) -> float:
        """
        Compute disk I/O pressure signal (0–100).

        Normalizes total disk ops/sec against a reference value. The reference
        starts at a default and should be calibrated from baseline data.
        """
        if self._disk_ops_reference <= 0:
            return 0.0

        # Ratio of current activity to reference baseline
        ratio = normalized.disk_total_ops_per_sec / self._disk_ops_reference

        # Apply a soft-clamp curve: pressure rises steeply beyond 1.0x reference
        # Using a sigmoid-like curve to prevent extreme outliers
        if ratio <= 0.5:
            pressure = ratio * 40.0  # 0–20 range for normal activity
        elif ratio <= 1.0:
            pressure = 20.0 + (ratio - 0.5) * 60.0  # 20–50 for moderate
        elif ratio <= 2.0:
            pressure = 50.0 + (ratio - 1.0) * 30.0  # 50–80 for heavy
        else:
            pressure = 80.0 + min(20.0, (ratio - 2.0) * 10.0)  # 80–100 for extreme

        return min(100.0, pressure)

    def _adapt_weights(
        self,
        cpu_pressure: float,
        memory_pressure: float,
        disk_pressure: float,
    ) -> dict[str, float]:
        """
        Dynamically adjust weights based on signal intensity.

        When one resource shows disproportionately high pressure (>80%),
        its weight is boosted by 20% and others are reduced proportionally.
        This ensures the stress score reflects the dominant bottleneck.
        """
        w_cpu = self._base_weight_cpu
        w_mem = self._base_weight_memory
        w_disk = self._base_weight_disk

        boost = 0.10  # 10% boost for dominant signal

        # Boost dominant signals
        high_threshold = 80.0
        dominant_count = sum(
            1
            for p in (cpu_pressure, memory_pressure, disk_pressure)
            if p >= high_threshold
        )

        if dominant_count > 0 and dominant_count < 3:
            # Only boost if not everything is high (which means even distribution)
            if cpu_pressure >= high_threshold:
                w_cpu += boost
            if memory_pressure >= high_threshold:
                w_mem += boost
            if disk_pressure >= high_threshold:
                w_disk += boost

        # Normalize so weights sum to 1.0
        total = w_cpu + w_mem + w_disk
        if total > 0:
            w_cpu /= total
            w_mem /= total
            w_disk /= total

        return {"cpu": w_cpu, "memory": w_mem, "disk": w_disk}

    @staticmethod
    def _classify_level(score: float) -> str:
        """Classify stress score into a human-readable level."""
        if score <= STRESS_LOW_THRESHOLD:
            return "low"
        elif score <= STRESS_MODERATE_THRESHOLD:
            return "moderate"
        elif score <= STRESS_HIGH_THRESHOLD:
            return "high"
        else:
            return "critical"
