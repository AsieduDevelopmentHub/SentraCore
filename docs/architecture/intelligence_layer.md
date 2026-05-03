# Intelligence Pipeline

This document explains how SentraCore transforms raw system telemetry into actionable, explainable intelligence across its ten processing stages.

---

## Overview

Raw telemetry alone is insufficient for meaningful system monitoring. A CPU reading of 95% could be normal during a scheduled batch job, or it could indicate a runaway process. SentraCore resolves this ambiguity through a sequential intelligence pipeline that layers context, statistics, and forecasting on top of raw data.

```
SystemCollector
    → Normalizer              (EMA smoothing, spike detection)
    → TimeSeriesBuffer        (ring buffers for historical context)
    → BaselineModel           (per-segment adaptive learning)
    → TrendAnalyzer           (linear regression, slope, volatility)
    → AnomalyDetector         (Z-score deviation from baseline)
    → StressEngine            (multi-state composite score)
    → PredictionEngine        (ETA forecasting, risk scoring)
    → StabilityCalculator     (global health index)
    → CorrelationEngine       (root cause analysis, triggered on alert)
    → AlertManager            (threshold evaluation, RCA attachment)
```

---

## Stage 1: System Collection

**Module:** `engine/collector/system_collector.py`

The `SystemCollector` samples system telemetry at a configurable interval (default: 2 seconds) using `psutil`. Each sample is a `SystemSnapshot` containing CPU percent, memory usage, disk I/O rates, and a UNIX timestamp.

---

## Stage 2: Normalization

**Module:** `engine/normalization/normalizer.py`

The `Normalizer` applies an **Exponential Moving Average (EMA)** to each metric, reducing the impact of instantaneous spikes on downstream analysis. It also independently detects spikes by comparing raw values against the rolling average.

---

## Stage 3: Time-Series Buffering

**Module:** `engine/buffer/time_series_buffer.py`

Normalized snapshots are pushed into two ring buffers:
- **Short-window buffer:** Last ~60 seconds, used for trend analysis.
- **Long-window buffer:** Last ~30 minutes, used for baseline learning.

---

## Stage 4: Baseline Learning

**Module:** `engine/baseline/baseline_model.py`

The `BaselineModel` learns what is *normal* for the specific machine. It segments the day into four time-of-day windows (Night, Morning, Afternoon, Evening) and maintains a running mean and standard deviation per metric per segment. Static thresholds are never used.

---

## Stage 5: Trend Analysis

**Module:** `engine/intelligence/trend_analyzer.py`

The `TrendAnalyzer` performs **linear regression** over the short-window buffer to compute CPU and Memory slope (% change per second) and volatility (short-term standard deviation). A positive, sustained memory slope can indicate a memory leak.

---

## Stage 6: Anomaly Detection

**Module:** `engine/intelligence/anomaly_detector.py`

The `AnomalyDetector` calculates a Z-Score for each metric against the active time-of-day baseline:

```
Z = (Current Value - Baseline Mean) / Baseline Standard Deviation
```

Anomalies must be sustained over multiple consecutive cycles before being classified as elevated or severe, preventing transient micro-spikes from generating false alerts.

---

## Stage 7: Multi-State Stress Engine

**Module:** `engine/stress/stress_engine.py`

The `StressEngine` consolidates upstream analysis into a single **Stress Score (0–100)** weighted across three dimensions:
1. Instantaneous resource pressure (CPU, Memory, Disk).
2. Trend modifiers (growing slopes add a forward-looking penalty).
3. Anomaly modifiers (sustained z-score deviations multiply the base pressure).

---

## Stage 8: Prediction & Risk Engine

**Module:** `engine/intelligence/prediction_engine.py`

The `PredictionEngine` uses EMA-smoothed trend slopes to forecast:
- **Time-to-Exhaustion (ETA):** Seconds until Memory hits 98% or CPU hits 95%.
- **Risk Score (0–100%):** Probabilistic assessment of severe degradation within the next 5 minutes.

---

## Stage 9: System Stability Index

**Module:** `engine/intelligence/stability_index.py`

The `StabilityCalculator` synthesises all upstream signals into a **System Stability Index (1–100)**. The index is a weighted composite of:
- **50%** Instantaneous Stress Score
- **30%** Predictive Risk Score
- **20%** Anomaly Score

---

## Stage 10: Correlation & Root Cause Analysis

**Module:** `engine/intelligence/correlation_engine.py`

Invoked lazily only when an alert fires, the `CorrelationEngine` cross-references three data sources:
1. **Bottleneck Identification:** Determines whether CPU, Memory, or Disk is the primary stressor.
2. **Suspect Identification:** Cross-references against the `ProcessTracker` to find the top-impact process.
3. **Trigger Identification:** Cross-references against the `EventLogger` to find the causal system event.

The resulting `RootCauseAnalysis` is attached to the `Alert` and broadcast via WebSocket to the dashboard.
