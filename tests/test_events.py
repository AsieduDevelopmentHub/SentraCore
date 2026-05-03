"""Tests for EventLogger."""

import time

from engine.collector.system_collector import ProcessInfo, SystemSnapshot
from engine.events.event_logger import EventLogger, SystemEvent
from engine.normalization.normalizer import NormalizedSnapshot


def _make_snapshot(procs=(), ts=None) -> SystemSnapshot:
    return SystemSnapshot(
        timestamp=ts or time.time(),
        cpu_percent=25.0,
        cpu_per_core=(25.0,),
        cpu_count_logical=1,
        memory_total=16_000_000_000,
        memory_used=8_000_000_000,
        memory_available=8_000_000_000,
        memory_percent=50.0,
        swap_total=4_000_000_000,
        swap_used=0,
        swap_percent=0.0,
        disk_read_bytes=0,
        disk_write_bytes=0,
        disk_read_count=0,
        disk_write_count=0,
        processes=tuple(procs),
    )


def _make_normalized(
    cpu_spike=False, mem_spike=False, disk_spike=False, ts=None
) -> NormalizedSnapshot:
    return NormalizedSnapshot(
        timestamp=ts or time.time(),
        cpu_percent_smoothed=50.0,
        memory_percent_smoothed=50.0,
        cpu_percent_raw=50.0,
        memory_percent_raw=50.0,
        memory_used=8_000_000_000,
        memory_available=8_000_000_000,
        memory_total=16_000_000_000,
        swap_percent=0.0,
        disk_read_bytes_per_sec=0.0,
        disk_write_bytes_per_sec=0.0,
        disk_read_ops_per_sec=0.0,
        disk_write_ops_per_sec=0.0,
        disk_total_bytes_per_sec=0.0,
        disk_total_ops_per_sec=0.0,
        cpu_is_spiking=cpu_spike,
        memory_is_spiking=mem_spike,
        disk_is_spiking=disk_spike,
    )


class TestEventLogger:
    def test_cpu_spike_event(self):
        logger = EventLogger()
        snap = _make_snapshot()
        norm = _make_normalized(cpu_spike=True)

        events = logger.analyze(snap, norm)
        cpu_events = [e for e in events if e.event_type == "cpu_spike"]
        assert len(cpu_events) == 1
        assert cpu_events[0].severity == "warning"

    def test_cpu_spike_no_duplicate(self):
        logger = EventLogger()
        snap = _make_snapshot()
        norm_spike = _make_normalized(cpu_spike=True)
        norm_normal = _make_normalized(cpu_spike=False)

        # First spike
        events1 = logger.analyze(snap, norm_spike)
        assert any(e.event_type == "cpu_spike" for e in events1)

        # Second spike - should not fire again (already active)
        events2 = logger.analyze(snap, norm_spike)
        spike_events = [e for e in events2 if e.event_type == "cpu_spike"]
        assert len(spike_events) == 0

        # Resolve
        events3 = logger.analyze(snap, norm_normal)
        resolve_events = [
            e for e in events3 if e.event_type == "cpu_spike" and e.severity == "info"
        ]
        assert len(resolve_events) == 1

    def test_process_start_detection(self):
        logger = EventLogger()
        proc1 = ProcessInfo(
            pid=100,
            name="a.exe",
            cpu_percent=10.0,
            memory_percent=5.0,
            memory_rss=100,
            status="running",
            create_time=1.0,
        )

        # First call establishes known pids
        logger.analyze(_make_snapshot(procs=[proc1]), _make_normalized())

        # Second call with new process
        proc2 = ProcessInfo(
            pid=200,
            name="b.exe",
            cpu_percent=5.0,
            memory_percent=3.0,
            memory_rss=50,
            status="running",
            create_time=2.0,
        )
        events = logger.analyze(
            _make_snapshot(procs=[proc1, proc2]), _make_normalized()
        )

        start_events = [e for e in events if e.event_type == "process_start"]
        assert len(start_events) == 1
        assert start_events[0].details["pid"] == 200

    def test_process_stop_detection(self):
        logger = EventLogger()
        proc1 = ProcessInfo(
            pid=100,
            name="a.exe",
            cpu_percent=10.0,
            memory_percent=5.0,
            memory_rss=100,
            status="running",
            create_time=1.0,
        )
        proc2 = ProcessInfo(
            pid=200,
            name="b.exe",
            cpu_percent=5.0,
            memory_percent=3.0,
            memory_rss=50,
            status="running",
            create_time=2.0,
        )

        # Establish both
        logger.analyze(_make_snapshot(procs=[proc1, proc2]), _make_normalized())

        # Remove proc2
        events = logger.analyze(_make_snapshot(procs=[proc1]), _make_normalized())
        stop_events = [e for e in events if e.event_type == "process_stop"]
        assert len(stop_events) == 1
        assert stop_events[0].details["pid"] == 200

    def test_get_recent_events(self):
        logger = EventLogger()
        snap = _make_snapshot()

        # Generate a spike event
        logger.analyze(snap, _make_normalized(cpu_spike=True))

        recent = logger.get_recent_events(10)
        assert len(recent) >= 1
        assert all(isinstance(e, SystemEvent) for e in recent)

    def test_clear(self):
        logger = EventLogger()
        logger.analyze(_make_snapshot(), _make_normalized(cpu_spike=True))
        logger.clear()

        assert logger.event_count == 0
