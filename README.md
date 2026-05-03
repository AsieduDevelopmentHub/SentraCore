# SentraCore

SentraCore is a **Local System Behavior Intelligence Platform** for Windows. It continuously analyzes system telemetry to understand performance behavior, detect statistical anomalies, explain the root cause of slowdowns, and forecast resource exhaustion before it occurs.

Unlike traditional monitoring tools that display raw snapshots, SentraCore interprets system behavior over time — answering not just *what* is happening, but *why* it is happening and *when* it will become critical.

---

## Current Status

**All six phases are complete and production-ready.**

| Phase | Name | Status |
|---|---|---|
| Phase 1 | Core Telemetry Engine | Complete |
| Phase 2 | Behavioral Intelligence Layer | Complete |
| Phase 3 | Correlation & Root Cause Engine | Complete |
| Phase 4 | Prediction & Risk Engine | Complete |
| Phase 5 | Flutter Dashboard System | Complete |
| Phase 6 | Productization Layer | Complete |

---

## What SentraCore Does

### System Stability Index
The primary dashboard metric is the **System Stability Index (1–100)**. Unlike a raw CPU percentage, this score synthesises instantaneous resource pressure, statistical anomaly deviation, and forward-looking predictive risk into a single, actionable number. A score of 100 is perfect health.

### Root Cause Analysis
When the system enters a high-stress state and an alert fires, SentraCore's Correlation Engine automatically generates a **Root Cause Analysis** — identifying the primary bottleneck (CPU, Memory, or Disk), the most likely offending process, and the system event that triggered the degradation.

### Predictive Forecasting
The Prediction Engine uses Exponential Moving Averages on trend slopes to generate **Time-to-Exhaustion (ETA)** countdowns. If memory is growing at a sustained rate, SentraCore will warn you that saturation is expected in X seconds, not just that usage is high.

### Adaptive Baseline Learning
SentraCore does not use static thresholds. It learns what is *normal* for the specific machine it runs on, segmented by time-of-day. A CPU spike at 2 AM during a known backup job is treated differently from the same spike at 2 PM.

---

## Architecture

SentraCore is structured as two decoupled layers communicating over a local WebSocket and REST API:

```
Flutter Dashboard (Windows Desktop)
         ↕  WebSocket (ws://localhost:8000/ws/live)
         ↕  REST API  (http://localhost:8000/api/v1/)
Python Engine (Headless Background Process)
    ├── SystemCollector      (psutil telemetry)
    ├── Normalizer           (EMA smoothing)
    ├── TimeSeriesBuffer     (ring buffers)
    ├── BaselineModel        (adaptive learning)
    ├── TrendAnalyzer        (linear regression)
    ├── AnomalyDetector      (Z-score analysis)
    ├── StressEngine         (multi-state composite)
    ├── PredictionEngine     (ETA forecasting)
    ├── StabilityCalculator  (global health index)
    ├── CorrelationEngine    (root cause analysis)
    └── AlertManager         (threshold evaluation)
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Monitoring Engine | Python 3.11, psutil |
| API Server | FastAPI, uvicorn |
| Real-time Communication | WebSockets |
| Dashboard UI | Flutter (Dart), Windows Desktop |
| Build & Packaging | PyInstaller, Inno Setup |
| CI/CD | GitHub Actions (ruff, pytest, flutter analyze) |
| Testing | pytest, flutter test |

---

## Getting Started

### Run in Development

See [docs/setup/development_setup.md](docs/setup/development_setup.md) for the full guide.

```powershell
# 1. Start the Python Engine
.venv\Scripts\python -m engine.main

# 2. In a second terminal, run the Flutter Dashboard
cd dashboard
flutter run -d windows
```

### Install from Installer

Download the latest `SentraCore_Setup.exe` from the [Releases](../../releases) page and run it. The installer will:
- Place both executables in `C:\Program Files\SentraCore\`.
- Optionally configure the engine to start automatically on Windows login.
- Create Desktop and Start Menu shortcuts for the dashboard.

---

## Documentation

| Document | Description |
|---|---|
| [Development Setup](docs/setup/development_setup.md) | Full local development environment guide |
| [Engine Setup](docs/setup/engine_setup.md) | Engine-specific installation reference |
| [Dashboard Setup](docs/setup/dashboard_setup.md) | Flutter-specific setup reference |
| [Intelligence Pipeline](docs/architecture/intelligence_layer.md) | Deep dive into all 10 processing stages |
| [Building SentraCore](docs/architecture/building.md) | How to produce production executables and the installer |

---

## Project Philosophy

SentraCore is built around five principles:

1. **Observation** — Collect accurate, smoothed system telemetry.
2. **Behavioral Modeling** — Understand what is normal for this machine.
3. **Anomaly Detection** — Detect statistically significant deviations.
4. **Correlation Analysis** — Explain *why* the system is degrading.
5. **Prediction** — Forecast *when* critical thresholds will be breached.

---

## License

Apache License.
