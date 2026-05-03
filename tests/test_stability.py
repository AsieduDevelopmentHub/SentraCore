"""Tests for the Phase 4 Stability Calculator."""

from engine.intelligence.stability_index import StabilityCalculator
from engine.intelligence.prediction_engine import PredictionResult
from engine.intelligence.anomaly_detector import AnomalyResult
from engine.stress.stress_engine import StressResult


def test_perfect_stability():
    calc = StabilityCalculator()

    stress = StressResult(0.0, "low", 0.0, 0.0, 0.0, {})
    prediction = PredictionResult(None, None, 0.0)
    anomaly = AnomalyResult(0.0, "normal", 0.0, 0.0, 0.0, False)

    result = calc.calculate(stress, prediction, anomaly)

    assert result.score == 100.0
    assert result.state == "stable"
    assert result.components["stress_penalty"] == 0.0
    assert result.components["risk_penalty"] == 0.0
    assert result.components["anomaly_penalty"] == 0.0


def test_degraded_stability():
    calc = StabilityCalculator(stress_weight=0.5, risk_weight=0.3, anomaly_weight=0.2)

    # High stress (80), high risk (50), low anomaly (10)
    stress = StressResult(80.0, "high", 0.0, 0.0, 0.0, {})
    prediction = PredictionResult(None, None, 50.0)
    anomaly = AnomalyResult(10.0, "normal", 0.0, 0.0, 0.0, False)

    result = calc.calculate(stress, prediction, anomaly)

    # Penalties: 80*0.5 = 40, 50*0.3 = 15, 10*0.2 = 2. Total = 57. Score = 100 - 57 = 43
    assert result.score == 43.0
    assert result.state == "degraded"


def test_critical_stability():
    calc = StabilityCalculator()

    stress = StressResult(100.0, "critical", 0.0, 0.0, 0.0, {})
    prediction = PredictionResult(None, None, 100.0)
    anomaly = AnomalyResult(100.0, "severe", 0.0, 0.0, 0.0, True)

    result = calc.calculate(stress, prediction, anomaly)

    assert result.score == 1.0  # Min score is 1.0
    assert result.state == "critical"
