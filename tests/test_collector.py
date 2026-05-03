"""Tests for SystemCollector."""

import time

from engine.collector.system_collector import (
    ProcessInfo,
    SystemCollector,
    SystemSnapshot,
)


class TestProcessInfo:
    """Test ProcessInfo dataclass."""

    def test_to_dict(self):
        proc = ProcessInfo(
            pid=1234,
            name="python.exe",
            cpu_percent=15.5,
            memory_percent=3.2,
            memory_rss=104857600,
            status="running",
            create_time=time.time(),
        )
        d = proc.to_dict()
        assert d["pid"] == 1234
        assert d["name"] == "python.exe"
        assert d["cpu_percent"] == 15.5
        assert d["memory_percent"] == 3.2


class TestSystemCollector:
    """Test SystemCollector telemetry collection."""

    def test_prime_and_collect(self):
        collector = SystemCollector()
        collector.prime()
        # Small delay for CPU delta
        time.sleep(0.1)
        snapshot = collector.collect()

        assert isinstance(snapshot, SystemSnapshot)
        assert snapshot.timestamp > 0
        assert 0 <= snapshot.cpu_percent <= 100 * snapshot.cpu_count_logical
        assert snapshot.memory_total > 0
        assert snapshot.memory_used > 0
        assert snapshot.memory_percent >= 0
        assert len(snapshot.cpu_per_core) == snapshot.cpu_count_logical

    def test_collect_without_prime_raises(self):
        collector = SystemCollector()
        try:
            collector.collect()
            assert False, "Should have raised RuntimeError"
        except RuntimeError:
            pass

    def test_snapshot_to_dict(self):
        collector = SystemCollector()
        collector.prime()
        time.sleep(0.1)
        snapshot = collector.collect()
        d = snapshot.to_dict()

        assert "timestamp" in d
        assert "cpu" in d
        assert "memory" in d
        assert "swap" in d
        assert "disk_io" in d
        assert "processes" in d
        assert isinstance(d["processes"], list)

    def test_processes_collected(self):
        collector = SystemCollector(max_processes=5)
        collector.prime()
        time.sleep(0.1)
        snapshot = collector.collect()

        assert len(snapshot.processes) <= 5
        if snapshot.processes:
            proc = snapshot.processes[0]
            assert isinstance(proc, ProcessInfo)
            assert proc.pid >= 0
