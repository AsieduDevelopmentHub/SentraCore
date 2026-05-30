# SentraCore 

[![RepoRanker](https://reporanker.com/badge/AsieduDevelopmentHub/SentraCore)](https://reporanker.com/repos/AsieduDevelopmentHub/SentraCore)

SentraCore is a local system behavior intelligence platform for Windows that continuously analyzes system telemetry to understand performance behavior, detect anomalies, explain system slowdowns, and estimate future resource pressure before it impacts usability.

Unlike traditional monitoring tools that focus on raw snapshots, SentraCore interprets system behavior over time — helping users understand what is happening, why it is happening, and how it may affect overall system responsiveness.

---

## Current Status

SentraCore currently includes:

- Real-time telemetry monitoring
- Behavioral baseline learning
- Statistical anomaly detection
- Root cause analysis
- Predictive risk estimation
- Historical monitoring (Logbook)
- Flutter desktop dashboard
- Windows installer and packaging system

---

## Core Features

### System Stability Index
Unified system health scoring based on:
- resource pressure
- anomaly deviation
- sustained stress trends
- predictive degradation risk

---

### Behavioral Intelligence
Learns normal system behavior per machine, including:
- CPU usage patterns
- memory behavior
- disk activity trends
- time-of-day workload patterns

---

### Root Cause Analysis
Analyzes:
- process activity
- resource contention
- event timing
- system degradation patterns

Provides ranked likely contributors instead of raw metrics alone.

---

### Predictive Forecasting
Estimates future resource exhaustion using trend analysis:
- memory saturation forecasting
- CPU trend projection
- disk pressure estimation
- ETA-style degradation warnings

---

### Historical Monitoring
Automatically records and visualizes:
- CPU pressure
- memory pressure
- disk pressure
- long-term behavior trends

---

### Alerts & Diagnostics
Includes:
- live alerts
- alert history
- diagnostics timeline
- Windows notifications
- root cause summaries

---

## Architecture

```text
Flutter Dashboard
        ↕ WebSocket / REST API
Python Intelligence Engine
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
| Engine | Python 3.11, psutil |
| API | FastAPI, WebSockets |
| Dashboard | Flutter Desktop |
| Packaging | PyInstaller, Inno Setup |
| CI/CD | GitHub Actions |

---

## Getting Started

### Development

See the setup documentation below for full instructions.

```powershell
# Start engine
.venv\Scripts\python -m engine.main

# Run dashboard
cd dashboard
flutter run -d windows
```

---

### Installer

Download the latest installer from the [GitHub Releases](https://github.com/AsieduDevelopmentHub/SentraCore/releases) page.

The installer:
- installs SentraCore
- creates shortcuts
- configures optional startup launch
- sets up the monitoring engine automatically

---

## Documentation

| Document | Description |
|---|---|
| [Development Setup](docs/setup/development_setup.md) | Full local development setup |
| [Engine Setup](docs/setup/engine_setup.md) | Engine configuration and setup |
| [Dashboard Setup](docs/setup/dashboard_setup.md) | Flutter dashboard setup |
| [Intelligence Pipeline](docs/architecture/intelligence_layer.md) | Internal intelligence architecture |
| [Building SentraCore](docs/architecture/building.md) | Packaging and installer process |

---

## Philosophy

SentraCore is built around six principles:

1. Observation  
2. Behavioral modeling  
3. Anomaly detection  
4. Correlation analysis  
5. Predictive awareness  
6. Forecasting  

---

## Prerequisites (quick glance)

| Requirement | Notes |
|---|---|
| Python | 3.11+ (see `requirements.txt` / `pyproject.toml`) |
| Flutter | Stable channel, 3.x+ for the desktop dashboard |
| OS | Windows is the primary packaging target; Linux and macOS are supported for development |

---

## License

Apache License 2.0
