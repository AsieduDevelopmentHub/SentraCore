"""Tests for the Phase 4 Prediction Engine."""

from engine.intelligence.prediction_engine import PredictionEngine
from engine.intelligence.trend_analyzer import TrendResult
from engine.normalization.normalizer import NormalizedSnapshot


def _make_snapshot(cpu: float = 10.0, mem: float = 50.0) -> NormalizedSnapshot:
    return NormalizedSnapshot(
        timestamp=100.0,
        cpu_percent_raw=cpu,
        cpu_percent_smoothed=cpu,
        cpu_is_spiking=False,
        memory_percent_raw=mem,
        memory_percent_smoothed=mem,
        memory_used=5000,
        memory_available=5000,
        memory_total=10000,
        memory_is_spiking=False,
        swap_percent=0.0,
        disk_total_ops_per_sec=0.0,
        disk_total_bytes_per_sec=0.0,
        disk_read_bytes_per_sec=0.0,
        disk_write_bytes_per_sec=0.0,
        disk_read_ops_per_sec=0.0,
        disk_write_ops_per_sec=0.0,
        disk_is_spiking=False,
    )


def test_prediction_exhaustion_eta():
    engine = PredictionEngine(
        smoothing_factor=1.0
    )  # 1.0 means no smoothing, just use raw slope

    # Simulate a rapid memory leak (1% per second growth)
    trend = TrendResult(
        cpu_slope=0.01, memory_slope=1.0, cpu_volatility=0.0, memory_volatility=0.0
    )

    # Current memory is 50%, exhaustion is 98%, so 48% remaining.
    # At 1% per second, ETA should be 48 seconds.
    snapshot = _make_snapshot(mem=50.0)

    result = engine.predict(trend, snapshot)
    assert result.memory_exhaustion_eta_sec == 48.0
    assert result.cpu_critical_eta_sec is None  # CPU slope too small to forecast


def test_prediction_risk_scoring():
    engine = PredictionEngine(smoothing_factor=1.0)

    trend = TrendResult(
        cpu_slope=2.0,  # Huge CPU spike
        memory_slope=0.0,
        cpu_volatility=0.0,
        memory_volatility=0.0,
    )

    snapshot = _make_snapshot(cpu=80.0)  # 15% to critical (95%). ETA = 7.5 seconds

    result = engine.predict(trend, snapshot)
    assert result.cpu_critical_eta_sec == 7.5
    # Since ETA < 30 seconds, risk score should increase by 60
    assert result.risk_score >= 60.0


def test_prediction_smoothing():
    engine = PredictionEngine(smoothing_factor=0.5)

    # Cycle 1
    trend1 = TrendResult(1.0, 1.0, 0, 0)
    engine.predict(trend1, _make_snapshot())
    assert engine._smoothed_cpu_slope == 1.0  # First value is raw

    # Cycle 2
    trend2 = TrendResult(0.0, 0.0, 0, 0)
    engine.predict(trend2, _make_snapshot())
    # EMA: 0.5 * 0 + 0.5 * 1.0 = 0.5
    assert engine._smoothed_cpu_slope == 0.5
