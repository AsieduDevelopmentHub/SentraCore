# SentraCore

SentraCore is a local system behavior intelligence platform for Windows that continuously analyzes system telemetry to understand performance behavior, detect statistical anomalies, explain performance degradation, and estimate future resource exhaustion before it impacts usability.

Unlike traditional monitoring tools that focus on raw real-time snapshots, SentraCore interprets system behavior over time — helping users understand not only what is happening, but also why it is happening, how severe it is, and how it may affect system responsiveness.

---

## Overview

SentraCore combines:

- Real-time telemetry collection
- Adaptive baseline learning
- Statistical anomaly detection
- Correlation-based root cause analysis
- Predictive resource forecasting
- Historical system behavior tracking
- User-impact focused diagnostics

The platform is designed as a lightweight local intelligence layer running continuously in the background with minimal overhead.

---

## Current Status

SentraCore is actively developed and currently includes a production-ready monitoring engine, behavioral intelligence system, predictive analysis pipeline, and Windows desktop dashboard.

| Layer | Status |
|---|---|
| Core Telemetry Engine | Stable |
| Behavioral Intelligence Layer | Stable |
| Correlation & Root Cause Analysis | Stable |
| Predictive Risk Engine | Stable |
| Flutter Desktop Dashboard | Stable |
| Windows Packaging & Installer | Stable |

---

## Core Capabilities

### System Stability Index

SentraCore generates a unified **System Stability Index (1–100)** representing overall system health.

The score combines:
- Resource pressure
- Behavioral deviation
- Sustained stress trends
- Predictive degradation risk

Rather than exposing isolated metrics, the Stability Index provides a high-level understanding of system condition and responsiveness.

---

### Behavioral Intelligence

The platform continuously models normal system behavior using adaptive baselines.

SentraCore learns:
- Typical CPU activity
- Memory consumption patterns
- Disk activity behavior
- Time-of-day workload trends

This allows the system to distinguish between expected workload spikes and abnormal behavior.

---

### Statistical Anomaly Detection

SentraCore uses statistical deviation analysis to identify abnormal system states.

Detection includes:
- Sustained deviation from baseline
- Resource volatility spikes
- Abnormal trend acceleration
- Multi-resource pressure correlation

Anomaly sensitivity can be configured by the user.

---

### Root Cause Analysis

When degradation events occur, the Correlation Engine analyzes:

- Process activity
- Resource contention
- System event timing
- Trend alignment

The engine then generates a ranked explanation of likely contributing factors.

Example:

- Elevated memory pressure from browser processes
- Increased disk activity from indexing services
- Sustained CPU saturation from background workloads

---

### Predictive Forecasting

SentraCore estimates future resource exhaustion using trend-based forecasting models.

Capabilities include:
- Memory saturation estimation
- CPU trend projection
- Disk pressure forecasting
- Time-to-exhaustion estimation (ETA)

This enables proactive alerts before severe degradation occurs.

---

### Historical Monitoring (Logbook)

The dashboard automatically records and visualizes historical system behavior over time.

Supported views include:
- CPU pressure history
- Memory pressure history
- Disk pressure history
- Interactive time filtering
- Date-range analysis

History is stored locally on the machine.

---

### Process Intelligence

Processes are evaluated using sustained impact analysis rather than instantaneous usage alone.

Features include:
- Process grouping by executable
- Sustained resource contribution tracking
- Ranked impact analysis
- Process lifecycle cleanup for stale PIDs
- Expandable per-process details

---

### Alerting & Diagnostics

SentraCore includes a real-time alerting and diagnostics system.

Features:
- Alert history tracking
- Root cause summaries
- WebSocket-powered live alerts
- Windows desktop notifications
- Diagnostics timeline integration

---

### Safeguard System (Optional)

An optional safeguard layer can automatically terminate selected user-approved processes during severe degradation scenarios.

Features:
- Live process selection
- Flexible executable matching
- User-controlled targeting
- Logged termination outcomes
- Safety-focused restrictions

---

## System Architecture

SentraCore is structured as two decoupled layers communicating over local APIs and WebSockets.

```text
Flutter Dashboard (Windows Desktop)
        ↕ WebSocket / REST API
Python Monitoring & Intelligence Engine
    ├── SystemCollector
    ├── SignalNormalizer
    ├── TimeSeriesBuffer
    ├── BaselineModel
    ├── TrendAnalyzer
    ├── AnomalyDetector
    ├── StressEngine
    ├── PredictionEngine
    ├── StabilityCalculator
    ├── CorrelationEngine
    ├── AlertManager
    └── SafeguardController
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Monitoring Engine | Python 3.11 |
| Telemetry Collection | psutil |
| API Server | FastAPI |
| Real-Time Communication | WebSockets |
| Dashboard UI | Flutter Desktop (Windows) |
| Packaging | PyInstaller |
| Installer | Inno Setup |
| CI/CD | GitHub Actions |
| Testing | pytest, flutter test |

---

## Installation

### Windows Installer

Download the latest installer from the [Releases](../../releases) page.

The installer:
- Installs SentraCore into `C:\Program Files\SentraCore\`
- Creates Desktop and Start Menu shortcuts
- Optionally enables startup launch behavior
- Configures the monitoring engine automatically

---

## Development Setup

See the setup documentation for complete local development instructions.

### Run the Engine

```powershell
.venv\Scripts\python -m engine.main
```

### Run the Dashboard

```powershell
cd dashboard
flutter run -d windows
```

---

## Documentation

| Document | Description |
|---|---|
| Development Setup | Local development environment setup |
| Engine Setup | Python engine configuration |
| Dashboard Setup | Flutter dashboard setup |
| Architecture Overview | Internal processing pipeline |
| Build & Packaging | Production build and installer process |

---

## Design Philosophy

SentraCore is built around five principles:

1. Observation  
   Collect reliable and structured telemetry.

2. Behavioral Modeling  
   Learn what is normal for the machine.

3. Anomaly Detection  
   Detect statistically significant deviations.

4. Correlation Analysis  
   Explain likely causes of degradation.

5. Predictive Awareness  
   Estimate future instability before impact occurs.

---

## Product Positioning

SentraCore is not a traditional monitoring dashboard.

It is a local system behavior intelligence platform focused on:

- behavioral understanding
- anomaly detection
- predictive system analysis
- explainable diagnostics
- user-impact interpretation

---

## License

Apache License 2.0