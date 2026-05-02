"""Tests for BaselineModel."""

import json
import tempfile
from pathlib import Path

from app.baseline.baseline_model import BaselineModel, BaselineStats, MetricStats
from app.normalization.normalizer import NormalizedSnapshot


def _make_normalized(cpu: float = 25.0, mem: float = 50.0, disk_ops: float = 100.0) -> NormalizedSnapshot:
    return NormalizedSnapshot(
        timestamp=1.0,
        cpu_percent_smoothed=cpu,
        memory_percent_smoothed=mem,
        cpu_percent_raw=cpu,
        memory_percent_raw=mem,
        memory_used=8_000_000_000,
        memory_available=8_000_000_000,
        memory_total=16_000_000_000,
        swap_percent=0.0,
        disk_read_bytes_per_sec=0.0,
        disk_write_bytes_per_sec=0.0,
        disk_read_ops_per_sec=disk_ops / 2,
        disk_write_ops_per_sec=disk_ops / 2,
        disk_total_bytes_per_sec=0.0,
        disk_total_ops_per_sec=disk_ops,
        cpu_is_spiking=False,
        memory_is_spiking=False,
        disk_is_spiking=False,
    )


class TestMetricStats:

    def test_welford_mean(self):
        stats = MetricStats()
        for v in [10.0, 20.0, 30.0]:
            stats.update(v)

        assert stats.count == 3
        assert abs(stats.mean - 20.0) < 0.001

    def test_welford_std_dev(self):
        stats = MetricStats()
        for v in [10.0, 10.0, 10.0]:
            stats.update(v)

        assert stats.std_dev == 0.0

    def test_min_max(self):
        stats = MetricStats()
        for v in [5.0, 15.0, 10.0]:
            stats.update(v)

        assert stats.min_val == 5.0
        assert stats.max_val == 15.0

    def test_serialization_roundtrip(self):
        stats = MetricStats()
        for v in [10.0, 20.0, 30.0, 40.0, 50.0]:
            stats.update(v)

        d = stats.to_dict()
        restored = MetricStats.from_dict(d)

        assert restored.count == stats.count
        assert abs(restored.mean - stats.mean) < 0.01


class TestBaselineModel:

    def test_not_ready_initially(self):
        model = BaselineModel(
            baseline_file=Path(tempfile.mktemp(suffix=".json")),
            min_samples=10,
        )
        assert model.is_ready is False

    def test_ready_after_min_samples(self):
        model = BaselineModel(
            baseline_file=Path(tempfile.mktemp(suffix=".json")),
            min_samples=5,
        )
        for _ in range(5):
            model.update(_make_normalized())

        assert model.is_ready is True
        assert model.sample_count == 5

    def test_deviation_detection(self):
        model = BaselineModel(
            baseline_file=Path(tempfile.mktemp(suffix=".json")),
            min_samples=5,
            deviation_sigma=2.0,
        )
        # Train with stable CPU around 30%
        for _ in range(10):
            model.update(_make_normalized(cpu=30.0))

        # 30% should not be deviated
        assert model.is_deviated("cpu_percent", 30.0) is False

        # 90% should be deviated (way above mean + 2σ with σ≈0)
        assert model.is_deviated("cpu_percent", 90.0) is True

    def test_deviation_returns_false_when_not_ready(self):
        model = BaselineModel(
            baseline_file=Path(tempfile.mktemp(suffix=".json")),
            min_samples=100,
        )
        model.update(_make_normalized(cpu=30.0))
        assert model.is_deviated("cpu_percent", 99.0) is False

    def test_persist_and_load(self):
        path = Path(tempfile.mktemp(suffix=".json"))
        model = BaselineModel(baseline_file=path, min_samples=3, persist_interval=1)

        for i in range(5):
            model.update(_make_normalized(cpu=20.0 + i))

        model.persist()
        assert path.exists()

        # Load into new model
        model2 = BaselineModel(baseline_file=path, min_samples=3)
        assert model2.is_ready is True
        assert model2.sample_count == 5

        # Cleanup
        path.unlink(missing_ok=True)

    def test_get_baseline(self):
        model = BaselineModel(
            baseline_file=Path(tempfile.mktemp(suffix=".json")),
            min_samples=3,
        )
        for _ in range(5):
            model.update(_make_normalized(cpu=40.0, mem=60.0, disk_ops=200.0))

        baseline = model.get_baseline()
        assert baseline["ready"] is True
        assert "stats" in baseline
        assert "cpu_percent" in baseline["stats"]

    def test_reset(self):
        model = BaselineModel(
            baseline_file=Path(tempfile.mktemp(suffix=".json")),
            min_samples=3,
        )
        for _ in range(5):
            model.update(_make_normalized())

        model.reset()
        assert model.is_ready is False
        assert model.sample_count == 0
