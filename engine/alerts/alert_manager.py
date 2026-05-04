"""
SentraCore — Alert Manager.

Generates alerts based on sustained resource pressure (CPU / memory / disk),
not instant spikes. An alert fires only when at least one signal exceeds its
configured threshold for a configurable number of consecutive readings. After
firing, a cooldown period prevents alert spam.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import TYPE_CHECKING, Callable

if TYPE_CHECKING:
    from engine.events.event_logger import SystemEvent

from engine.config import (
    ALERT_CONSECUTIVE_COUNT,
    ALERT_COOLDOWN_SEC,
    COLLECTION_INTERVAL_SEC,
)
from engine.process.process_tracker import ProcessImpact
from engine.stress.stress_engine import StressResult
from engine.user_preferences import UserPreferences

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class Alert:
    """System stress alert with context."""

    timestamp: float
    stress_score: float
    level: str
    top_contributors: tuple[ProcessImpact, ...]
    message: str
    root_cause: dict | None = None

    def to_dict(self) -> dict:
        return {
            "timestamp": self.timestamp,
            "stress_score": round(self.stress_score, 2),
            "level": self.level,
            "top_contributors": [c.to_dict() for c in self.top_contributors],
            "message": self.message,
            "root_cause": self.root_cause,
        }


AlertCallback = Callable[["Alert"], None]


class AlertManager:
    """
    Fires when CPU, memory, or disk pressure (each 0–100) exceeds user thresholds
    for N consecutive collection cycles, and cooldown allows it.
    """

    def __init__(
        self,
        consecutive_count: int = ALERT_CONSECUTIVE_COUNT,
        cooldown_sec: float = ALERT_COOLDOWN_SEC,
    ) -> None:
        self._required_consecutive = consecutive_count
        self._cooldown_sec = cooldown_sec

        self._consecutive_high: int = 0
        self._last_alert_time: float = 0.0
        self._callbacks: list[AlertCallback] = []
        self._total_alerts: int = 0
        self._alert_history = []

        from engine.intelligence.correlation_engine import CorrelationEngine

        self._correlation_engine = CorrelationEngine()

    def register_callback(self, callback: AlertCallback) -> None:
        self._callbacks.append(callback)
        logger.debug("Alert callback registered. Total: %d", len(self._callbacks))

    def get_recent_alerts(self, limit: int = 10) -> list[Alert]:
        return list(reversed(self._alert_history[-limit:]))

    @staticmethod
    def _resource_breach(stress: StressResult, prefs: UserPreferences) -> bool:
        return (
            stress.cpu_pressure >= prefs.alert_cpu_percent
            or stress.memory_pressure >= prefs.alert_memory_percent
            or stress.disk_pressure >= prefs.alert_disk_pressure
        )

    @staticmethod
    def _breach_summary(stress: StressResult, prefs: UserPreferences) -> list[str]:
        parts: list[str] = []
        if stress.cpu_pressure >= prefs.alert_cpu_percent:
            parts.append(
                f"CPU pressure {stress.cpu_pressure:.0f}% "
                f"(threshold {prefs.alert_cpu_percent:.0f}%)"
            )
        if stress.memory_pressure >= prefs.alert_memory_percent:
            parts.append(
                f"Memory pressure {stress.memory_pressure:.0f}% "
                f"(threshold {prefs.alert_memory_percent:.0f}%)"
            )
        if stress.disk_pressure >= prefs.alert_disk_pressure:
            parts.append(
                f"Disk pressure {stress.disk_pressure:.0f}% "
                f"(threshold {prefs.alert_disk_pressure:.0f}%)"
            )
        return parts

    def evaluate(
        self,
        stress: StressResult,
        top_processes: list[ProcessImpact],
        recent_events: list["SystemEvent"] | None = None,
        prefs: UserPreferences | None = None,
    ) -> Alert | None:
        now = time.time()
        recent_events = recent_events or []
        prefs = prefs if prefs is not None else UserPreferences.default()

        if self._resource_breach(stress, prefs):
            self._consecutive_high += 1
        else:
            self._consecutive_high = 0
            return None

        if self._consecutive_high < self._required_consecutive:
            return None

        if (now - self._last_alert_time) < self._cooldown_sec:
            return None

        rca = self._correlation_engine.analyze(stress, top_processes, recent_events)

        self._last_alert_time = now
        self._total_alerts += 1

        sustained_sec = self._consecutive_high * COLLECTION_INTERVAL_SEC
        breach_txt = "; ".join(self._breach_summary(stress, prefs))
        message = (
            f"Resource alert ({breach_txt}). "
            f"Stress {stress.level} ({stress.score:.0f}/100), sustained ~{sustained_sec:.0f}s. "
            f"Root cause: {rca.summary}"
        )

        alert = Alert(
            timestamp=now,
            stress_score=stress.score,
            level=stress.level,
            top_contributors=tuple(top_processes[:5]),
            message=message,
            root_cause=rca.to_dict(),
        )

        self._alert_history.append(alert)
        if len(self._alert_history) > 50:
            self._alert_history.pop(0)

        for callback in self._callbacks:
            try:
                callback(alert)
            except Exception as exc:
                logger.error("Alert callback failed: %s", exc)

        logger.warning("ALERT: %s", message)
        return alert

    @property
    def total_alerts(self) -> int:
        return self._total_alerts

    @property
    def is_in_cooldown(self) -> bool:
        if self._last_alert_time <= 0:
            return False
        return self.cooldown_remaining_sec > 0

    @property
    def cooldown_total_sec(self) -> float:
        return float(self._cooldown_sec)

    @property
    def cooldown_remaining_sec(self) -> float:
        if self._last_alert_time <= 0:
            return 0.0
        rem = self._cooldown_sec - (time.time() - self._last_alert_time)
        return max(0.0, rem)

    @property
    def consecutive_high_count(self) -> int:
        return self._consecutive_high

    def reset(self) -> None:
        self._consecutive_high = 0
        self._last_alert_time = 0.0
        self._total_alerts = 0
