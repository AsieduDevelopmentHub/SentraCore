"""
SentraCore — Correlation & Root Cause Engine.

Analyzes system state (stress, anomalies, trends, processes, and events)
to determine *why* the system is experiencing stress, generating a
human-readable Root Cause Analysis (RCA) report.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from engine.events.event_logger import SystemEvent
    from engine.process.process_tracker import ProcessImpact
    from engine.stress.stress_engine import StressResult

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class RootCauseAnalysis:
    """Detailed explanation of why the system is stressed."""

    primary_bottleneck: str
    suspect_process: dict | None
    trigger_event: dict | None
    confidence_score: float
    summary: str

    def to_dict(self) -> dict:
        return {
            "primary_bottleneck": self.primary_bottleneck,
            "suspect_process": self.suspect_process,
            "trigger_event": self.trigger_event,
            "confidence_score": round(self.confidence_score, 2),
            "summary": self.summary,
        }


class CorrelationEngine:
    """
    Correlates high-stress signals with specific processes and events
    to generate Root Cause Analysis reports.
    """

    def analyze(
        self,
        stress: 'StressResult',
        top_processes: list['ProcessImpact'],
        recent_events: list['SystemEvent'],
    ) -> RootCauseAnalysis:
        """
        Perform root cause analysis based on current context.
        Should only be called when stress is significantly elevated.
        """
        # 1. Identify Primary Bottleneck
        bottleneck = self._identify_bottleneck(stress)

        # 2. Identify Suspect Process
        suspect = self._identify_suspect(bottleneck, top_processes)

        # 3. Identify Trigger Event
        trigger = self._identify_trigger(bottleneck, suspect, recent_events)

        # 4. Calculate Confidence
        confidence = self._calculate_confidence(bottleneck, suspect, trigger)

        # 5. Generate Summary
        summary = self._generate_summary(bottleneck, suspect, trigger)

        return RootCauseAnalysis(
            primary_bottleneck=bottleneck,
            suspect_process=suspect.to_dict() if suspect else None,
            trigger_event=trigger.to_dict() if trigger else None,
            confidence_score=confidence,
            summary=summary,
        )

    def _identify_bottleneck(self, stress: 'StressResult') -> str:
        """Find the resource under the most pressure."""
        pressures = {
            "cpu": stress.cpu_pressure,
            "memory": stress.memory_pressure,
            "disk": stress.disk_pressure,
        }
        return max(pressures.items(), key=lambda item: item[1])[0]

    def _identify_suspect(
        self, bottleneck: str, top_processes: list['ProcessImpact']
    ) -> 'ProcessImpact | None':
        """Find the process most likely causing the bottleneck."""
        if not top_processes:
            return None

        # Sort processes based on the bottleneck resource
        if bottleneck == "cpu":
            candidates = sorted(top_processes, key=lambda p: p.avg_cpu_percent, reverse=True)
            # Only suspect if it's taking a significant chunk (e.g., > 15%)
            if candidates and candidates[0].avg_cpu_percent > 15.0:
                return candidates[0]
                
        elif bottleneck == "memory":
            candidates = sorted(top_processes, key=lambda p: p.avg_memory_percent, reverse=True)
            if candidates and candidates[0].avg_memory_percent > 10.0:
                return candidates[0]
                
        elif bottleneck == "disk":
            # We don't track per-process disk IO yet, so fallback to highest impact
            candidates = sorted(top_processes, key=lambda p: p.impact_score, reverse=True)
            if candidates:
                return candidates[0]

        return None

    def _identify_trigger(
        self, bottleneck: str, suspect: 'ProcessImpact | None', recent_events: list['SystemEvent']
    ) -> 'SystemEvent | None':
        """Find a recent event that explains the bottleneck."""
        if not recent_events:
            return None
            
        # Search backwards (most recent first)
        for event in reversed(recent_events):
            # If we have a suspect, see if there's a process_started event for it
            if suspect and event.event_type == "process_started":
                if event.details.get("pid") == suspect.pid or event.details.get("name") == suspect.name:
                    return event
                    
            # Correlate generic events to the bottleneck
            if bottleneck == "memory" and event.event_type in ("high_swap_usage", "memory_spike"):
                return event
            elif bottleneck == "cpu" and event.event_type == "cpu_spike":
                return event
            elif bottleneck == "disk" and event.event_type == "disk_io_spike":
                return event
                
        return None

    def _calculate_confidence(
        self, bottleneck: str, suspect: 'ProcessImpact | None', trigger: 'SystemEvent | None'
    ) -> float:
        """Calculate confidence (0-100%) in the RCA."""
        score = 20.0  # Base confidence for finding a bottleneck
        
        if suspect:
            score += 50.0  # Strong confidence if we have a culprit process
            
        if trigger:
            score += 30.0  # Extra confidence if we have a matching event
            
        return score

    def _generate_summary(
        self, bottleneck: str, suspect: 'ProcessImpact | None', trigger: 'SystemEvent | None'
    ) -> str:
        """Generate human-readable explanation."""
        summary = f"System is experiencing critical {bottleneck.upper()} pressure."
        
        if suspect:
            metric = f"{suspect.avg_cpu_percent:.1f}% CPU" if bottleneck == "cpu" else f"{suspect.avg_memory_percent:.1f}% Memory"
            summary += f" The process '{suspect.name}' (PID {suspect.pid}) is the primary suspect, consuming {metric}."
            
        if trigger:
            if trigger.event_type == "process_started":
                summary += " This pressure began shortly after the process was launched."
            else:
                summary += f" A '{trigger.event_type}' event was detected recently."
                
        return summary
