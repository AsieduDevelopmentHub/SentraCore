"""
SentraCore — System Stability Index Calculator.

Computes a global, unified metric of system health (1-100) by blending
instantaneous stress, statistical anomalies, and predictive risk.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from engine.intelligence.anomaly_detector import AnomalyResult
    from engine.intelligence.prediction_engine import PredictionResult
    from engine.stress.stress_engine import StressResult

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class StabilityIndex:
    """Unified system health score."""

    score: float       # 1-100 (100 = perfect, 1 = critical)
    state: str         # "stable", "degraded", "critical"
    components: dict   # Breakdown of the penalty points

    def to_dict(self) -> dict:
        return {
            "score": round(self.score, 1),
            "state": self.state,
            "components": self.components,
        }


class StabilityCalculator:
    """
    Computes System Stability Index.
    
    100 means the system is perfectly stable.
    Lower scores indicate increasing levels of degradation.
    """

    def __init__(
        self,
        stress_weight: float = 0.5,
        risk_weight: float = 0.3,
        anomaly_weight: float = 0.2,
    ) -> None:
        self._w_stress = stress_weight
        self._w_risk = risk_weight
        self._w_anomaly = anomaly_weight

        # Ensure weights sum to 1.0
        total = self._w_stress + self._w_risk + self._w_anomaly
        self._w_stress /= total
        self._w_risk /= total
        self._w_anomaly /= total

    def calculate(
        self,
        stress: 'StressResult',
        prediction: 'PredictionResult',
        anomaly: 'AnomalyResult',
    ) -> StabilityIndex:
        """
        Calculate global stability score.
        """
        # Calculate penalty points from each component (0-100)
        stress_penalty = stress.score * self._w_stress
        risk_penalty = prediction.risk_score * self._w_risk
        anomaly_penalty = anomaly.score * self._w_anomaly

        total_penalty = stress_penalty + risk_penalty + anomaly_penalty

        # Stability is the inverse of the penalty
        score = max(1.0, 100.0 - total_penalty)

        # Determine state
        if score >= 80.0:
            state = "stable"
        elif score >= 40.0:
            state = "degraded"
        else:
            state = "critical"

        return StabilityIndex(
            score=score,
            state=state,
            components={
                "stress_penalty": round(stress_penalty, 1),
                "risk_penalty": round(risk_penalty, 1),
                "anomaly_penalty": round(anomaly_penalty, 1),
            },
        )
