"""Tests for Normalizer."""

import time

from engine.collector.system_collector import SystemSnapshot
from engine.normalization.normalizer import NormalizedSnapshot, Normalizer


def _make_snapshot(
    cpu: float = 25.0,
    mem_pct: float = 50.0,
    disk_read_bytes: int = 0,
    disk_write_bytes: int = 0,
    disk_read_count: int = 0,
    disk_write_count: int = 0,
    ts: float | None = None,
) -> SystemSnapshot:
    return SystemSnapshot(
        timestamp=ts or time.time(),
        cpu_percent=cpu,
        cpu_per_core=(cpu,),
        cpu_count_logical=1,
        memory_total=16_000_000_000,
        memory_used=8_000_000_000,
        memory_available=8_000_000_000,
        memory_percent=mem_pct,
        swap_total=4_000_000_000,
        swap_used=0,
        swap_percent=0.0,
        disk_read_bytes=disk_read_bytes,
        disk_write_bytes=disk_write_bytes,
        disk_read_count=disk_read_count,
        disk_write_count=disk_write_count,
        processes=(),
    )


class TestNormalizer:
    def test_first_normalize_initializes_ema(self):
        norm = Normalizer(alpha=0.3)
        snap = _make_snapshot(cpu=50.0, mem_pct=60.0)
        result = norm.normalize(snap)

        assert isinstance(result, NormalizedSnapshot)
        # First call: EMA == raw value
        assert result.cpu_percent_smoothed == 50.0
        assert result.memory_percent_smoothed == 60.0

    def test_ema_smoothing(self):
        norm = Normalizer(alpha=0.5)
        norm.normalize(_make_snapshot(cpu=40.0, ts=1.0))
        result = norm.normalize(_make_snapshot(cpu=60.0, ts=3.0))

        # EMA = 0.5 * 60 + 0.5 * 40 = 50
        assert result.cpu_percent_smoothed == 50.0

    def test_disk_rate_computation(self):
        norm = Normalizer()
        # First snapshot: baseline
        norm.normalize(
            _make_snapshot(
                disk_read_bytes=1000,
                disk_write_bytes=2000,
                disk_read_count=10,
                disk_write_count=20,
                ts=1.0,
            )
        )
        # Second snapshot: 2 seconds later
        result = norm.normalize(
            _make_snapshot(
                disk_read_bytes=3000,
                disk_write_bytes=4000,
                disk_read_count=30,
                disk_write_count=40,
                ts=3.0,
            )
        )

        # Delta over 2 seconds
        assert result.disk_read_bytes_per_sec == 1000.0  # (3000-1000)/2
        assert result.disk_write_bytes_per_sec == 1000.0  # (4000-2000)/2
        assert result.disk_read_ops_per_sec == 10.0  # (30-10)/2
        assert result.disk_write_ops_per_sec == 10.0  # (40-20)/2

    def test_first_disk_rates_are_zero(self):
        norm = Normalizer()
        result = norm.normalize(_make_snapshot(disk_read_bytes=5000, ts=1.0))

        assert result.disk_read_bytes_per_sec == 0.0
        assert result.disk_write_bytes_per_sec == 0.0

    def test_spike_detection_requires_consecutive(self):
        norm = Normalizer(alpha=1.0, min_spike_readings=3)

        # One reading above threshold — not a spike yet
        r1 = norm.normalize(_make_snapshot(cpu=90.0, ts=1.0))
        assert r1.cpu_is_spiking is False

        # Second
        r2 = norm.normalize(_make_snapshot(cpu=90.0, ts=3.0))
        assert r2.cpu_is_spiking is False

        # Third — now it's confirmed
        r3 = norm.normalize(_make_snapshot(cpu=90.0, ts=5.0))
        assert r3.cpu_is_spiking is True

    def test_spike_resets_on_drop(self):
        norm = Normalizer(alpha=1.0, min_spike_readings=2)

        norm.normalize(_make_snapshot(cpu=90.0, ts=1.0))
        norm.normalize(_make_snapshot(cpu=90.0, ts=3.0))
        r = norm.normalize(_make_snapshot(cpu=90.0, ts=5.0))
        assert r.cpu_is_spiking is True

        # Drop below threshold
        r = norm.normalize(_make_snapshot(cpu=30.0, ts=7.0))
        assert r.cpu_is_spiking is False

    def test_to_dict(self):
        norm = Normalizer()
        result = norm.normalize(_make_snapshot(cpu=45.0, mem_pct=55.0, ts=1.0))
        d = result.to_dict()

        assert "cpu" in d
        assert "memory" in d
        assert "disk_io" in d
        assert d["cpu"]["raw"] == 45.0

    def test_reset(self):
        norm = Normalizer()
        norm.normalize(_make_snapshot(cpu=50.0, ts=1.0))
        norm.reset()

        # After reset, should behave like first call
        result = norm.normalize(_make_snapshot(cpu=80.0, ts=3.0))
        assert result.cpu_percent_smoothed == 80.0
