"""Tests for TimeSeriesBuffer."""

import time

from engine.buffer.time_series_buffer import TimeSeriesBuffer
from engine.collector.system_collector import SystemSnapshot


def _make_snapshot(cpu: float = 25.0, mem_pct: float = 50.0, ts: float | None = None) -> SystemSnapshot:
    """Create a minimal test snapshot."""
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
        disk_read_bytes=0,
        disk_write_bytes=0,
        disk_read_count=0,
        disk_write_count=0,
        processes=(),
    )


class TestTimeSeriesBuffer:

    def test_push_and_retrieve(self):
        buf = TimeSeriesBuffer(short_size=10, long_size=20)
        snap = _make_snapshot()
        buf.push(snap)

        assert buf.short_count == 1
        assert buf.long_count == 1
        assert buf.get_latest() == snap

    def test_short_buffer_eviction(self):
        buf = TimeSeriesBuffer(short_size=3, long_size=100)
        for i in range(5):
            buf.push(_make_snapshot(cpu=float(i * 10)))

        assert buf.short_count == 3
        assert buf.long_count == 5

        # Short buffer should have the 3 most recent
        cpus = buf.get_short_window_field("cpu_percent")
        assert cpus == [20.0, 30.0, 40.0]

    def test_long_buffer_eviction(self):
        buf = TimeSeriesBuffer(short_size=3, long_size=5)
        for i in range(7):
            buf.push(_make_snapshot(cpu=float(i * 10)))

        assert buf.long_count == 5
        cpus = buf.get_long_window_field("cpu_percent")
        assert cpus == [20.0, 30.0, 40.0, 50.0, 60.0]

    def test_get_latest_empty(self):
        buf = TimeSeriesBuffer(short_size=5, long_size=10)
        assert buf.get_latest() is None

    def test_field_extraction(self):
        buf = TimeSeriesBuffer(short_size=10, long_size=10)
        buf.push(_make_snapshot(cpu=10.0, mem_pct=40.0))
        buf.push(_make_snapshot(cpu=20.0, mem_pct=50.0))

        cpus = buf.get_short_window_field("cpu_percent")
        mems = buf.get_short_window_field("memory_percent")

        assert cpus == [10.0, 20.0]
        assert mems == [40.0, 50.0]

    def test_clear(self):
        buf = TimeSeriesBuffer(short_size=10, long_size=10)
        buf.push(_make_snapshot())
        buf.push(_make_snapshot())
        buf.clear()

        assert buf.short_count == 0
        assert buf.long_count == 0

    def test_capacity(self):
        buf = TimeSeriesBuffer(short_size=150, long_size=1800)
        assert buf.short_capacity == 150
        assert buf.long_capacity == 1800
