"""Tests for ProcessTracker."""

from engine.collector.system_collector import ProcessInfo
from engine.process.process_tracker import ProcessImpact, ProcessTracker


def _make_proc(pid: int, name: str, cpu: float, mem: float) -> ProcessInfo:
    return ProcessInfo(
        pid=pid,
        name=name,
        cpu_percent=cpu,
        memory_percent=mem,
        memory_rss=100_000_000,
        status="running",
        create_time=1.0,
    )


class TestProcessTracker:
    def test_update_and_get_top(self):
        tracker = ProcessTracker(window_size=5, top_count=3)
        procs = (
            _make_proc(1, "chrome.exe", 30.0, 10.0),
            _make_proc(2, "python.exe", 15.0, 5.0),
            _make_proc(3, "vscode.exe", 5.0, 20.0),
        )
        tracker.update(procs)
        top = tracker.get_top_consumers()

        assert len(top) == 3
        assert all(isinstance(p, ProcessImpact) for p in top)
        # First should have highest impact score
        assert top[0].impact_score >= top[1].impact_score

    def test_sustained_ranking(self):
        tracker = ProcessTracker(window_size=3, top_count=2)

        # Round 1: Chrome is high
        tracker.update(
            (
                _make_proc(1, "chrome.exe", 80.0, 5.0),
                _make_proc(2, "python.exe", 5.0, 5.0),
            )
        )
        # Round 2: Chrome drops, python rises
        tracker.update(
            (
                _make_proc(1, "chrome.exe", 10.0, 5.0),
                _make_proc(2, "python.exe", 50.0, 5.0),
            )
        )
        # Round 3: Chrome is low, python is high
        tracker.update(
            (
                _make_proc(1, "chrome.exe", 10.0, 5.0),
                _make_proc(2, "python.exe", 50.0, 5.0),
            )
        )

        top = tracker.get_top_consumers(2)
        # Python should rank higher due to sustained usage
        python_impact = next(p for p in top if p.name == "python.exe")
        chrome_impact = next(p for p in top if p.name == "chrome.exe")
        assert python_impact.impact_score > chrome_impact.impact_score

    def test_process_churn(self):
        tracker = ProcessTracker(window_size=5)

        # First round: 2 processes
        tracker.update(
            (_make_proc(1, "a.exe", 10.0, 5.0), _make_proc(2, "b.exe", 20.0, 10.0))
        )
        assert tracker.get_active_count() == 2

        # Second round: process 1 gone, process 3 new
        tracker.update(
            (_make_proc(2, "b.exe", 20.0, 10.0), _make_proc(3, "c.exe", 5.0, 5.0))
        )
        assert tracker.get_active_count() == 2

    def test_impact_to_dict(self):
        tracker = ProcessTracker(window_size=3)
        tracker.update((_make_proc(1, "test.exe", 25.0, 10.0),))

        top = tracker.get_top_consumers(1)
        d = top[0].to_dict()
        assert "pid" in d
        assert "name" in d
        assert "impact_score" in d

    def test_reset(self):
        tracker = ProcessTracker(window_size=5)
        tracker.update((_make_proc(1, "a.exe", 10.0, 5.0),))
        tracker.reset()

        assert tracker.get_active_count() == 0
        assert tracker.get_top_consumers() == []

    def test_prune_after_missing_from_snapshots(self):
        """PID not in collector top list for N cycles is dropped (exited or fell out)."""
        tracker = ProcessTracker(window_size=3, miss_prune_snapshots=3)
        tracker.update((_make_proc(1, "gone.exe", 50.0, 10.0),))
        assert 1 in [p.pid for p in tracker.get_top_consumers(5)]

        tracker.update((_make_proc(2, "other.exe", 40.0, 10.0),))
        tracker.update((_make_proc(2, "other.exe", 40.0, 10.0),))
        tracker.update((_make_proc(2, "other.exe", 40.0, 10.0),))

        assert 1 not in [p.pid for p in tracker.get_top_consumers(5)]
