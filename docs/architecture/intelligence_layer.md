# Intelligence Pipeline

This document explains how SentraCore transforms raw system telemetry into structured, explainable system intelligence through a multi-stage processing pipeline.

Rather than relying on isolated system snapshots, SentraCore continuously analyzes behavior over time to detect anomalies, estimate degradation risk, and identify likely causes of system slowdowns.

---

# Overview

Raw telemetry alone rarely provides meaningful context.

For example:
- High CPU usage may be expected during compilation or rendering workloads
- Elevated memory usage may indicate either normal caching behavior or sustained resource pressure
- Temporary disk spikes may be harmless, while prolonged saturation may degrade responsiveness

SentraCore addresses this by processing telemetry through multiple intelligence layers that progressively add context, statistical interpretation, behavioral analysis, and forecasting.

---

# Pipeline Flow

```text
SystemCollector
    → SignalNormalizer
    → TimeSeriesBuffer
    → BaselineModel
    → TrendAnalyzer
    → AnomalyDetector
    → StressEngine
    → PredictionEngine
    → StabilityCalculator
    → CorrelationEngine
    → AlertManager
```

---

# Stage 1 — System Collection

**Module:** `engine/collector/system_collector.py`

The `SystemCollector` gathers real-time system telemetry at a configurable interval using `psutil`.

Collected metrics include:
- CPU utilization
- memory usage
- disk activity
- process statistics
- system timestamps

Each cycle produces a structured `SystemSnapshot` used throughout the pipeline.

---

# Stage 2 — Signal Normalization

**Module:** `engine/normalization/normalizer.py`

Raw system telemetry often contains short-lived spikes and noisy fluctuations.

The `SignalNormalizer` applies smoothing techniques such as:
- Exponential Moving Average (EMA)
- rolling averages
- spike filtering

This improves downstream stability while still preserving meaningful trend changes.

The normalization layer also detects sudden metric spikes separately from sustained behavior changes.

---

# Stage 3 — Time-Series Buffering

**Module:** `engine/buffer/time_series_buffer.py`

Normalized snapshots are stored in rolling time-series buffers.

SentraCore maintains:
- short-term buffers for real-time analysis
- long-term buffers for behavioral modeling

These buffers provide historical context for:
- trend analysis
- baseline learning
- anomaly detection
- forecasting

---

# Stage 4 — Baseline Learning

**Module:** `engine/baseline/baseline_model.py`

The `BaselineModel` learns what is considered normal for the current machine.

Instead of relying on static thresholds, SentraCore continuously adapts to:
- workload patterns
- hardware capabilities
- time-of-day behavior
- sustained usage characteristics

The baseline model tracks:
- average resource behavior
- deviation ranges
- historical variability

This reduces false positives and improves anomaly accuracy.

---

# Stage 5 — Trend Analysis

**Module:** `engine/intelligence/trend_analyzer.py`

The `TrendAnalyzer` evaluates how system behavior changes over time.

Analysis includes:
- slope calculation
- growth rate estimation
- short-term volatility
- sustained trend direction

Examples:
- continuously rising memory usage
- sustained CPU growth
- increasing disk saturation

Trend analysis provides early indicators of degradation before hard limits are reached.

---

# Stage 6 — Anomaly Detection

**Module:** `engine/intelligence/anomaly_detector.py`

The `AnomalyDetector` compares current behavior against the learned baseline.

Detection methods include:
- Z-score deviation analysis
- sustained abnormality detection
- volatility analysis
- multi-metric deviation scoring

SentraCore avoids reacting to isolated spikes by requiring anomalies to persist across multiple cycles before escalation.

Anomalies are categorized into severity bands such as:
- normal
- elevated
- high
- severe

---

# Stage 7 — Stress Engine

**Module:** `engine/stress/stress_engine.py`

The `StressEngine` consolidates multiple system signals into a unified stress representation.

Inputs include:
- instantaneous resource pressure
- anomaly severity
- trend acceleration
- sustained instability

The resulting stress score reflects both current pressure and ongoing degradation patterns.

---

# Stage 8 — Prediction & Risk Analysis

**Module:** `engine/intelligence/prediction_engine.py`

The `PredictionEngine` estimates future degradation risk using trend-based forecasting.

Forecasting includes:
- memory saturation estimation
- CPU trend projection
- disk pressure forecasting
- time-to-exhaustion (ETA)

The engine also produces a probabilistic degradation risk score representing the likelihood of severe instability within a future time window.

Predictions are probabilistic rather than deterministic.

---

# Stage 9 — System Stability Calculation

**Module:** `engine/intelligence/stability_index.py`

The `StabilityCalculator` generates the final System Stability Index.

The index combines:
- current stress state
- predictive risk
- anomaly severity
- sustained trend behavior

The resulting score provides a high-level representation of overall system responsiveness and health.

---

# Stage 10 — Correlation & Root Cause Analysis

**Module:** `engine/intelligence/correlation_engine.py`

The `CorrelationEngine` attempts to explain why degradation is occurring.

When alerts are triggered, the engine correlates:
- process activity
- resource contention
- event timing
- system pressure changes

The engine identifies:
- likely bottlenecks
- high-impact processes
- correlated system events

Outputs are probability-based explanations rather than absolute causality claims.

---

# Alert Pipeline

**Module:** `engine/alerts/alert_manager.py`

The `AlertManager` evaluates:
- sustained stress conditions
- anomaly escalation
- predictive risk thresholds

When thresholds are exceeded:
- alerts are generated
- root cause summaries are attached
- dashboard notifications are triggered
- events are stored in alert history

---

# Design Principles

The intelligence pipeline is designed around several core principles:

1. Time-Based Understanding  
   System behavior is analyzed over time rather than through isolated snapshots.

2. Adaptive Modeling  
   Behavior is evaluated relative to machine-specific baselines.

3. Statistical Interpretation  
   Signals are interpreted probabilistically rather than through fixed assumptions.

4. Explainability  
   Outputs prioritize understandable diagnostics instead of opaque scoring.

5. Predictive Awareness  
   The system estimates future degradation risk before severe instability occurs.

---

# Summary

SentraCore transforms low-level telemetry into layered behavioral intelligence through:

- normalization
- historical modeling
- anomaly detection
- trend analysis
- forecasting
- correlation analysis
- explainable diagnostics

This enables a deeper understanding of system behavior than traditional real-time monitoring alone.