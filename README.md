<div align="center">

# SentraCore

### System Behavior Intelligence Platform

SentraCore is a local **system behavior intelligence platform** designed to continuously analyze telemetry, understand performance behavior, detect anomalies, explain slowdowns, and estimate future system pressure before it impacts responsiveness.

Rather than focusing on isolated resource snapshots, SentraCore interprets system activity over time to answer three critical questions:

**What is happening?**  
**Why is it happening?**  
**What is likely to happen next?**

Built for intelligent desktop observability and explainable operational insight.

</div>

---

## Overview

SentraCore combines telemetry collection, behavioral modeling, anomaly detection, predictive analytics, and explainable diagnostics into a unified local intelligence system.

The platform continuously learns machine-specific operating patterns and transforms raw system measurements into actionable insights.

---

## Current Capabilities

SentraCore currently includes:

- Real-time telemetry monitoring
- Adaptive behavioral baseline learning
- Statistical anomaly detection
- Root cause analysis
- Predictive risk estimation
- Historical monitoring and logbook tracking
- Flutter desktop dashboard
- Desktop packaging and installer workflow

---

## Core Features

### System Stability Index

Unified system health scoring generated from:

- Resource pressure
- Behavioral deviation
- Sustained stress trends
- Predictive degradation indicators

---

### Behavioral Intelligence

Learns normal operating behavior per machine, including:

- CPU utilization patterns
- Memory behavior
- Disk activity trends
- Time-based workload characteristics

The objective is to detect meaningful deviation rather than isolated spikes.

---

### Root Cause Analysis

Correlates multiple signals to identify likely contributors to degradation.

Analysis includes:

- Process activity
- Resource contention
- Event timing
- Performance degradation patterns

Outputs ranked probable causes instead of raw metric streams.

---

### Predictive Forecasting

Forecasts future pressure using historical and trend-based analysis.

Includes:

- Memory saturation estimation
- CPU trend projection
- Disk pressure forecasting
- Estimated degradation warnings

---

### Historical Monitoring

Continuously records and visualizes:

- CPU pressure
- Memory pressure
- Disk pressure
- Long-term behavioral trends
- Historical intelligence events

---

### Alerts & Diagnostics

Includes:

- Live alerts
- Alert history
- Diagnostics timeline
- Windows notifications
- Root cause summaries

---

## Architecture

```text
Flutter Dashboard
        ↕
 WebSocket / REST API
        ↕
Python Intelligence Engine
│
├── Telemetry Collection
├── Baseline Learning
├── Anomaly Detection
├── Correlation Engine
├── Prediction Engine
└── Alert System
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Engine | Python 3.11 · psutil |
| API | FastAPI · WebSockets |
| Dashboard | Flutter Desktop |
| Packaging | PyInstaller · Inno Setup |
| Automation | GitHub Actions |

---

## Getting Started

### Development Environment

See project documentation for full setup instructions.

Start the engine:

```powershell
.venv\Scripts\python -m engine.main
```

Launch dashboard:

```powershell
cd dashboard

flutter run -d windows
```

---

## Installer

Download the latest desktop release from:

```text
GitHub Releases
```

Installer capabilities:

- Installs SentraCore
- Creates application shortcuts
- Configures optional startup behavior
- Deploys the monitoring engine
- Prepares runtime dependencies

---

## Documentation

| Document | Description |
|---|---|
| `docs/setup/development_setup.md` | Development environment setup |
| `docs/setup/engine_setup.md` | Engine installation and configuration |
| `docs/setup/dashboard_setup.md` | Dashboard build and execution |
| `docs/architecture/intelligence_layer.md` | Intelligence pipeline internals |
| `docs/architecture/building.md` | Packaging and release workflow |

---

## Design Principles

SentraCore is built around six guiding principles:

1. Observation  
2. Behavioral Modeling  
3. Pattern Recognition  
4. Correlation Analysis  
5. Predictive Awareness  
6. Explainable Intelligence  

---

## Requirements

| Requirement | Version |
|---|---|
| Python | 3.11+ |
| Flutter | Stable 3.x+ |
| Platform | Windows (Primary) |

Linux and macOS currently support development workflows but Windows remains the primary runtime and packaging target.

---

## Repository Structure

```text
engine/
dashboard/
docs/
installer/
pages/
assets/
tests/
```

---

## License

Licensed under the Apache License 2.0.

See:

[LICENSE](./LICENSE)

---

<div align="center">

### SentraCore

Observe • Understand • Predict

Intelligence Beyond Monitoring

</div>