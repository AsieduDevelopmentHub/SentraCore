"""Tests for the Phase 3 Correlation Engine."""

from engine.intelligence.correlation_engine import CorrelationEngine
from engine.stress.stress_engine import StressResult
from engine.process.process_tracker import ProcessImpact
from engine.events.event_logger import SystemEvent

def test_correlation_identifies_cpu_bottleneck():
    engine = CorrelationEngine()
    
    stress = StressResult(
        score=85.0,
        level="high",
        cpu_pressure=95.0,
        memory_pressure=20.0,
        disk_pressure=10.0,
        weights={"cpu": 0.8, "memory": 0.1, "disk": 0.1}
    )
    
    procs = [
        ProcessImpact(
            pid=1234,
            name="chrome.exe",
            avg_cpu_percent=45.0,
            avg_memory_percent=5.0,
            peak_cpu_percent=50.0,
            peak_memory_percent=10.0,
            current_cpu_percent=45.0,
            current_memory_percent=5.0,
            sample_count=10,
            impact_score=50.0
        ),
        ProcessImpact(
            pid=5678,
            name="explorer.exe",
            avg_cpu_percent=2.0,
            avg_memory_percent=1.0,
            peak_cpu_percent=5.0,
            peak_memory_percent=2.0,
            current_cpu_percent=2.0,
            current_memory_percent=1.0,
            sample_count=10,
            impact_score=3.0
        )
    ]
    
    events = [
        SystemEvent(
            timestamp=100.0,
            event_type="process_start",
            severity="info",
            details={"pid": 1234, "name": "chrome.exe"}
        ),
        SystemEvent(
            timestamp=105.0,
            event_type="cpu_spike",
            severity="warning",
            details={}
        )
    ]
    
    rca = engine.analyze(stress, procs, events)
    
    assert rca.primary_bottleneck == "cpu"
    assert rca.suspect_process is not None
    assert rca.suspect_process["pid"] == 1234
    assert rca.trigger_event is not None
    assert rca.trigger_event["event_type"] == "cpu_spike" # The latest matching event

def test_correlation_identifies_memory_bottleneck():
    engine = CorrelationEngine()
    
    stress = StressResult(
        score=90.0,
        level="critical",
        cpu_pressure=10.0,
        memory_pressure=98.0,
        disk_pressure=5.0,
        weights={"cpu": 0.1, "memory": 0.8, "disk": 0.1}
    )
    
    procs = [
        ProcessImpact(
            pid=9999,
            name="docker.exe",
            avg_cpu_percent=1.0,
            avg_memory_percent=60.0,
            peak_cpu_percent=5.0,
            peak_memory_percent=70.0,
            current_cpu_percent=1.0,
            current_memory_percent=65.0,
            sample_count=10,
            impact_score=61.0
        )
    ]
    
    rca = engine.analyze(stress, procs, [])
    
    assert rca.primary_bottleneck == "memory"
    assert rca.suspect_process is not None
    assert rca.suspect_process["name"] == "docker.exe"
    assert rca.trigger_event is None
    assert rca.confidence_score == 70.0  # 20 (bottleneck) + 50 (suspect) + 0 (trigger)
