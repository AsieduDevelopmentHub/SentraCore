"""Tests for AlertManager."""

import time

from engine.alerts.alert_manager import Alert, AlertManager
from engine.process.process_tracker import ProcessImpact
from engine.stress.stress_engine import StressResult


def _make_stress(score: float, level: str = "high") -> StressResult:
    return StressResult(
        score=score, level=level,
        cpu_pressure=score, memory_pressure=score * 0.5, disk_pressure=score * 0.3,
        weights={"cpu": 0.4, "memory": 0.35, "disk": 0.25},
    )


def _make_process(name: str = "test.exe") -> ProcessImpact:
    return ProcessImpact(
        pid=1, name=name,
        avg_cpu_percent=30.0, avg_memory_percent=10.0,
        peak_cpu_percent=50.0, peak_memory_percent=15.0,
        current_cpu_percent=30.0, current_memory_percent=10.0,
        sample_count=5, impact_score=22.0,
    )


class TestAlertManager:

    def test_no_alert_on_low_stress(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=3)
        result = mgr.evaluate(_make_stress(30.0, "low"), [_make_process()])
        assert result is None

    def test_no_alert_before_consecutive_threshold(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=3, cooldown_sec=0.0)

        # Two readings — not enough
        mgr.evaluate(_make_stress(80.0), [_make_process()])
        result = mgr.evaluate(_make_stress(80.0), [_make_process()])
        assert result is None

    def test_alert_fires_at_consecutive_threshold(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=3, cooldown_sec=0.0)

        mgr.evaluate(_make_stress(80.0), [_make_process()])
        mgr.evaluate(_make_stress(80.0), [_make_process()])
        result = mgr.evaluate(_make_stress(80.0), [_make_process()])

        assert isinstance(result, Alert)
        assert result.stress_score == 80.0
        assert "sustained" in result.message.lower()

    def test_cooldown_prevents_spam(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=2, cooldown_sec=60.0)

        mgr.evaluate(_make_stress(80.0), [_make_process()])
        alert1 = mgr.evaluate(_make_stress(80.0), [_make_process()])
        assert alert1 is not None

        # Subsequent high readings should not alert (cooldown)
        alert2 = mgr.evaluate(_make_stress(80.0), [_make_process()])
        assert alert2 is None
        assert mgr.is_in_cooldown is True

    def test_consecutive_resets_on_drop(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=3, cooldown_sec=0.0)

        mgr.evaluate(_make_stress(80.0), [_make_process()])
        mgr.evaluate(_make_stress(80.0), [_make_process()])
        # Drop below threshold — resets counter
        mgr.evaluate(_make_stress(50.0, "moderate"), [_make_process()])
        result = mgr.evaluate(_make_stress(80.0), [_make_process()])

        assert result is None  # Only 1 consecutive, needs 3

    def test_callback_called(self):
        alerts_received = []
        mgr = AlertManager(threshold=70.0, consecutive_count=1, cooldown_sec=0.0)
        mgr.register_callback(lambda a: alerts_received.append(a))

        mgr.evaluate(_make_stress(80.0), [_make_process()])
        assert len(alerts_received) == 1

    def test_total_alerts_counter(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=1, cooldown_sec=0.0)
        mgr.evaluate(_make_stress(80.0), [_make_process()])
        mgr.evaluate(_make_stress(80.0), [_make_process()])

        assert mgr.total_alerts == 2

    def test_alert_to_dict(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=1, cooldown_sec=0.0)
        alert = mgr.evaluate(_make_stress(85.0), [_make_process("chrome.exe")])

        d = alert.to_dict()
        assert "timestamp" in d
        assert "stress_score" in d
        assert "top_contributors" in d
        assert "message" in d
        assert "root_cause" in d
        assert d["root_cause"] is not None
        assert "primary_bottleneck" in d["root_cause"]

    def test_reset(self):
        mgr = AlertManager(threshold=70.0, consecutive_count=1, cooldown_sec=60.0)
        mgr.evaluate(_make_stress(80.0), [_make_process()])
        mgr.reset()

        assert mgr.total_alerts == 0
        assert mgr.is_in_cooldown is False
        assert mgr.consecutive_high_count == 0
