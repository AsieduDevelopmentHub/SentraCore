"""
SentraCore — Alert Manager.

Generates alerts based on sustained system stress, not instant spikes.
An alert fires only when the stress score exceeds a threshold for a
configurable number of consecutive readings. After firing, a cooldown
period prevents alert spam.

Alerts are emitted via registered callbacks (e.g., WebSocket broadcast).
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Callable

from app.config import (
    ALERT_CONSECUTIVE_COUNT,
    ALERT_COOLDOWN_SEC,
    ALERT_STRESS_THRESHOLD,
)
from app.process.process_tracker import ProcessImpact
from app.stress.stress_engine import StressResult

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class Alert:
    """System stress alert with context."""

    timestamp: float
    stress_score: float
    level: str
    top_contributors: tuple[ProcessImpact, ...]
    message: str

    def to_dict(self) -> dict:
        return {
            "timestamp": self.timestamp,
            "stress_score": round(self.stress_score, 2),
            "level": self.level,
            "top_contributors": [c.to_dict() for c in self.top_contributors],
            "message": self.message,
        }


# Type alias for alert callback functions
AlertCallback = Callable[[Alert], None]


class AlertManager:
    """
    Manages sustained-stress alert detection and emission.

    An alert fires when:
    1. Stress score > threshold for N consecutive readings
    2. Cooldown period has elapsed since the last alert

    Callbacks can be registered to receive alerts (e.g., the WebSocket
    layer registers a broadcast callback).
    """

    def __init__(
        self,
        threshold: float = ALERT_STRESS_THRESHOLD,
        consecutive_count: int = ALERT_CONSECUTIVE_COUNT,
        cooldown_sec: float = ALERT_COOLDOWN_SEC,
    ) -> None:
        self._threshold = threshold
        self._required_consecutive = consecutive_count
        self._cooldown_sec = cooldown_sec

        self._consecutive_high: int = 0
        self._last_alert_time: float = 0.0
        self._callbacks: list[AlertCallback] = []
        self._total_alerts: int = 0

    def register_callback(self, callback: AlertCallback) -> None:
        """Register a function to be called when an alert fires."""
        self._callbacks.append(callback)
        logger.debug("Alert callback registered. Total: %d", len(self._callbacks))

    def evaluate(
        self,
        stress: StressResult,
        top_processes: list[ProcessImpact],
    ) -> Alert | None:
        """
        Evaluate whether an alert should fire based on current stress.

        Args:
            stress: Current stress score result.
            top_processes: Current top resource consumers.

        Returns:
            Alert if one was triggered, None otherwise.
        """
        now = time.time()

        if stress.score >= self._threshold:
            self._consecutive_high += 1
        else:
            self._consecutive_high = 0
            return None

        # Check if we've hit the consecutive threshold
        if self._consecutive_high < self._required_consecutive:
            return None

        # Check cooldown
        if (now - self._last_alert_time) < self._cooldown_sec:
            return None

        # ----- Fire Alert -----
        self._last_alert_time = now
        self._total_alerts += 1

        # Build context message
        contributors_str = ", ".join(
            f"{p.name} ({p.avg_cpu_percent:.1f}% CPU)"
            for p in top_processes[:3]
        )
        message = (
            f"System stress {stress.level} ({stress.score:.0f}/100) "
            f"sustained for {self._consecutive_high * 2}s. "
            f"Top contributors: {contributors_str or 'N/A'}"
        )

        alert = Alert(
            timestamp=now,
            stress_score=stress.score,
            level=stress.level,
            top_contributors=tuple(top_processes[:5]),
            message=message,
        )

        # Notify all registered callbacks
        for callback in self._callbacks:
            try:
                callback(alert)
            except Exception as exc:
                logger.error("Alert callback failed: %s", exc)

        logger.warning("ALERT: %s", message)
        return alert

    @property
    def total_alerts(self) -> int:
        """Total number of alerts fired since startup."""
        return self._total_alerts

    @property
    def is_in_cooldown(self) -> bool:
        """Whether the alert manager is currently in cooldown."""
        return (time.time() - self._last_alert_time) < self._cooldown_sec

    @property
    def consecutive_high_count(self) -> int:
        """Current consecutive high-stress reading count."""
        return self._consecutive_high

    def reset(self) -> None:
        """Reset alert state (but keep callbacks)."""
        self._consecutive_high = 0
        self._last_alert_time = 0.0
        self._total_alerts = 0
