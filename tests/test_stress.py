"""Tests for StressEngine."""

from app.normalization.normalizer import NormalizedSnapshot
from app.stress.stress_engine import StressEngine, StressResult


def _make_normalized(
    cpu: float = 25.0,
    mem_pct: float = 50.0,
    mem_available: int = 8_000_000_000,
    mem_total: int = 16_000_000_000,
    disk_ops: float = 50.0,
    swap_pct: float = 0.0,
) -> NormalizedSnapshot:
    return NormalizedSnapshot(
        timestamp=1.0,
        cpu_percent_smoothed=cpu,
        memory_percent_smoothed=mem_pct,
        cpu_percent_raw=cpu,
        memory_percent_raw=mem_pct,
        memory_used=mem_total - mem_available,
        memory_available=mem_available,
        memory_total=mem_total,
        swap_percent=swap_pct,
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


class TestStressEngine:

    def test_low_stress(self):
        engine = StressEngine()
        result = engine.compute(_make_normalized(cpu=10.0, mem_pct=30.0, disk_ops=10.0))

        assert isinstance(result, StressResult)
        assert result.score < 30
        assert result.level == "low"

    def test_moderate_stress(self):
        engine = StressEngine()
        result = engine.compute(_make_normalized(cpu=50.0, mem_pct=60.0, disk_ops=200.0))

        assert 30 <= result.score <= 70
        assert result.level in ("moderate", "high")

    def test_high_stress(self):
        engine = StressEngine()
        result = engine.compute(_make_normalized(
            cpu=90.0, mem_pct=90.0, mem_available=1_600_000_000,
            mem_total=16_000_000_000, disk_ops=800.0
        ))

        assert result.score > 60
        assert result.level in ("high", "critical")

    def test_score_bounded(self):
        engine = StressEngine()
        result = engine.compute(_make_normalized(cpu=100.0, mem_pct=99.0, disk_ops=5000.0))

        assert 0 <= result.score <= 100

    def test_weights_sum_to_one(self):
        engine = StressEngine()
        result = engine.compute(_make_normalized(cpu=85.0, mem_pct=30.0, disk_ops=50.0))

        weight_sum = sum(result.weights.values())
        assert abs(weight_sum - 1.0) < 0.001

    def test_to_dict(self):
        engine = StressEngine()
        result = engine.compute(_make_normalized(cpu=40.0))
        d = result.to_dict()

        assert "score" in d
        assert "level" in d
        assert "pressures" in d
        assert "weights" in d

    def test_adaptive_weights_boost_dominant(self):
        engine = StressEngine()
        # CPU very high, others low
        result = engine.compute(_make_normalized(cpu=95.0, mem_pct=20.0, disk_ops=10.0))

        # CPU weight should be boosted above default 0.40
        assert result.weights["cpu"] > 0.40

    def test_set_disk_ops_reference(self):
        engine = StressEngine()
        engine.set_disk_ops_reference(100.0)

        # Same disk ops but different reference = different pressure
        r1 = engine.compute(_make_normalized(disk_ops=200.0))

        engine.set_disk_ops_reference(1000.0)
        r2 = engine.compute(_make_normalized(disk_ops=200.0))

        assert r1.disk_pressure > r2.disk_pressure
