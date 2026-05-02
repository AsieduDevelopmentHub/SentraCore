"""
SentraCore — Lightweight Baseline Model.

Tracks per-machine normal behavior using Welford's online algorithm
for running mean and standard deviation. Persists to disk so baselines
survive restarts.

Tracked metrics: CPU%, memory%, disk ops/sec.
"""

from __future__ import annotations

import json
import logging
import math
from dataclasses import dataclass, field
from pathlib import Path

from app.config import (
    BASELINE_DEVIATION_SIGMA,
    BASELINE_FILE,
    BASELINE_MIN_SAMPLES,
    BASELINE_PERSIST_INTERVAL,
    DATASTORE_DIR,
)
from app.normalization.normalizer import NormalizedSnapshot

logger = logging.getLogger(__name__)


@dataclass
class MetricStats:
    """Running statistics for a single metric using Welford's algorithm."""

    count: int = 0
    mean: float = 0.0
    m2: float = 0.0        # Sum of squares of differences from mean
    min_val: float = float("inf")
    max_val: float = float("-inf")

    @property
    def variance(self) -> float:
        if self.count < 2:
            return 0.0
        return self.m2 / (self.count - 1)

    @property
    def std_dev(self) -> float:
        return math.sqrt(self.variance)

    def update(self, value: float) -> None:
        """Update running stats with a new observation."""
        self.count += 1
        delta = value - self.mean
        self.mean += delta / self.count
        delta2 = value - self.mean
        self.m2 += delta * delta2
        self.min_val = min(self.min_val, value)
        self.max_val = max(self.max_val, value)

    def to_dict(self) -> dict:
        return {
            "count": self.count,
            "mean": round(self.mean, 4),
            "std_dev": round(self.std_dev, 4),
            "min": round(self.min_val, 4) if self.min_val != float("inf") else None,
            "max": round(self.max_val, 4) if self.max_val != float("-inf") else None,
        }

    @classmethod
    def from_dict(cls, data: dict) -> MetricStats:
        stats = cls()
        stats.count = data.get("count", 0)
        stats.mean = data.get("mean", 0.0)
        stats.min_val = data.get("min") if data.get("min") is not None else float("inf")
        stats.max_val = data.get("max") if data.get("max") is not None else float("-inf")
        # Reconstruct m2 from std_dev and count
        std = data.get("std_dev", 0.0)
        if stats.count >= 2:
            stats.m2 = (std ** 2) * (stats.count - 1)
        return stats


@dataclass
class BaselineStats:
    """Collection of baseline statistics for all tracked metrics."""

    cpu_percent: MetricStats = field(default_factory=MetricStats)
    memory_percent: MetricStats = field(default_factory=MetricStats)
    disk_ops_per_sec: MetricStats = field(default_factory=MetricStats)

    def to_dict(self) -> dict:
        return {
            "cpu_percent": self.cpu_percent.to_dict(),
            "memory_percent": self.memory_percent.to_dict(),
            "disk_ops_per_sec": self.disk_ops_per_sec.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: dict) -> BaselineStats:
        stats = cls()
        if "cpu_percent" in data:
            stats.cpu_percent = MetricStats.from_dict(data["cpu_percent"])
        if "memory_percent" in data:
            stats.memory_percent = MetricStats.from_dict(data["memory_percent"])
        if "disk_ops_per_sec" in data:
            stats.disk_ops_per_sec = MetricStats.from_dict(data["disk_ops_per_sec"])
        return stats


class BaselineModel:
    """
    Tracks normal system behavior and detects deviations.

    Uses Welford's online algorithm for numerically stable running
    statistics without storing all historical values.
    """

    def __init__(
        self,
        baseline_file: Path = BASELINE_FILE,
        min_samples: int = BASELINE_MIN_SAMPLES,
        deviation_sigma: float = BASELINE_DEVIATION_SIGMA,
        persist_interval: int = BASELINE_PERSIST_INTERVAL,
    ) -> None:
        self._file = baseline_file
        self._min_samples = min_samples
        self._sigma = deviation_sigma
        self._persist_interval = persist_interval
        self._update_count = 0

        # Load existing baseline or start fresh
        self._stats = self._load()

    @property
    def is_ready(self) -> bool:
        """Whether enough samples have been collected for reliable baseline."""
        return self._stats.cpu_percent.count >= self._min_samples

    @property
    def sample_count(self) -> int:
        return self._stats.cpu_percent.count

    def update(self, normalized: NormalizedSnapshot) -> None:
        """
        Update baseline statistics with a new normalized snapshot.

        Automatically persists to disk at configured intervals.
        """
        self._stats.cpu_percent.update(normalized.cpu_percent_smoothed)
        self._stats.memory_percent.update(normalized.memory_percent_smoothed)
        self._stats.disk_ops_per_sec.update(normalized.disk_total_ops_per_sec)

        self._update_count += 1
        if self._update_count % self._persist_interval == 0:
            self.persist()

    def is_deviated(self, metric: str, value: float) -> bool:
        """
        Check if a value deviates significantly from the baseline.

        Returns False if baseline is not yet ready (not enough samples).

        Args:
            metric: One of "cpu_percent", "memory_percent", "disk_ops_per_sec".
            value: Current metric value to check.

        Returns:
            True if value exceeds mean + sigma * std_dev.
        """
        if not self.is_ready:
            return False

        stats = self._get_metric_stats(metric)
        if stats is None:
            return False

        # When std_dev is 0 (all identical readings), any value above mean is deviated
        if stats.std_dev == 0:
            return value > stats.mean

        threshold = stats.mean + self._sigma * stats.std_dev
        return value > threshold

    def get_baseline(self) -> dict:
        """Return current baseline statistics as a dictionary."""
        return {
            "ready": self.is_ready,
            "sample_count": self.sample_count,
            "min_samples_required": self._min_samples,
            "stats": self._stats.to_dict(),
        }

    def persist(self) -> None:
        """Save baseline statistics to disk."""
        try:
            DATASTORE_DIR.mkdir(parents=True, exist_ok=True)
            data = self._stats.to_dict()
            self._file.write_text(json.dumps(data, indent=2), encoding="utf-8")
            logger.debug("Baseline persisted to %s (%d samples)", self._file, self.sample_count)
        except OSError as exc:
            logger.error("Failed to persist baseline: %s", exc)

    def _load(self) -> BaselineStats:
        """Load baseline from disk, or return empty stats."""
        if self._file.exists():
            try:
                data = json.loads(self._file.read_text(encoding="utf-8"))
                stats = BaselineStats.from_dict(data)
                logger.info(
                    "Loaded baseline from %s (%d samples)",
                    self._file,
                    stats.cpu_percent.count,
                )
                return stats
            except (json.JSONDecodeError, KeyError, OSError) as exc:
                logger.warning("Failed to load baseline, starting fresh: %s", exc)
        return BaselineStats()

    def _get_metric_stats(self, metric: str) -> MetricStats | None:
        """Resolve metric name to its MetricStats instance."""
        mapping = {
            "cpu_percent": self._stats.cpu_percent,
            "memory_percent": self._stats.memory_percent,
            "disk_ops_per_sec": self._stats.disk_ops_per_sec,
        }
        return mapping.get(metric)

    def reset(self) -> None:
        """Reset baseline to empty state."""
        self._stats = BaselineStats()
        self._update_count = 0
        logger.info("Baseline model reset.")
