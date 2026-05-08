# SentraCore Engine Setup

The SentraCore engine is a headless Python-based monitoring and intelligence service responsible for:

- collecting system telemetry
- analyzing behavioral trends
- detecting anomalies
- generating predictive insights
- serving live data through local REST and WebSocket interfaces

The engine operates independently from the dashboard and can run in the background as a standalone local service.

---

# Supported Platforms

| Platform | Support Status |
|---|---|
| Windows | Primary Support |
| Linux | Supported |
| macOS | Supported |

Some telemetry metrics may vary slightly across operating systems depending on the system APIs exposed through `psutil`.

---

# Prerequisites

## General Requirements

- Python 3.11 or higher
- Git

Verify Python installation:

```bash
python --version
```

or on Linux/macOS:

```bash
python3 --version
```

---

# Repository Structure

```text
engine/
├── alerts/            # Alerting and RCA integration
├── api/               # REST API and WebSocket server
├── baseline/          # Adaptive baseline learning
├── buffer/            # Time-series buffers
├── collector/         # Telemetry collection
├── events/            # Event tracking and logging
├── intelligence/      # Trend, anomaly, prediction engines
├── normalization/     # Signal normalization
├── process/           # Process intelligence tracking
├── safeguard/         # Optional safeguard controls
├── stress/            # Stress and stability calculation
└── main.py            # Engine entry point
```

---

# Installation

All commands should be executed from the repository root.

---

## 1. Create a Virtual Environment

### Windows

```powershell
python -m venv .venv
```

### Linux / macOS

```bash
python3 -m venv .venv
```

---

## 2. Activate the Virtual Environment

### Windows

```powershell
.venv\Scripts\Activate
```

### Linux / macOS

```bash
source .venv/bin/activate
```

---

## 3. Install Dependencies

```bash
pip install -r requirements.txt
```

---

# Running the Engine

The engine must be started as a module from the repository root so internal package imports resolve correctly.

### Windows

```powershell
.venv\Scripts\python -m engine.main
```

### Linux / macOS

```bash
python -m engine.main
```

---

# Engine Startup Behavior

When launched, the engine will:

- initialize telemetry collectors
- load user preferences and baseline data
- start the FastAPI server
- initialize the WebSocket broadcaster
- begin the monitoring and intelligence pipeline
- start event and alert tracking

The engine runs continuously until stopped manually.

---

# Available Interfaces

Once running, the engine exposes the following local interfaces.

## REST API

| Endpoint | Description |
|---|---|
| `GET /api/v1/status` | Current system state snapshot |
| `GET /api/v1/processes` | Top ranked processes by impact |
| `GET /api/v1/events` | Recent system events |
| `GET /api/v1/alerts` | Alert history and RCA summaries |
| `GET /api/v1/preferences` | Current user preferences |
| `PUT /api/v1/preferences` | Update persisted preferences |

Default local address:

```text
http://localhost:8740/api/v1/
```

---

## WebSocket

| Endpoint | Description |
|---|---|
| `WS /ws/live` | Real-time system state stream |

Default endpoint:

```text
ws://localhost:8740/ws/live
```

---

# Dynamic Port Allocation

If port `8740` is already in use, the engine automatically searches for the next available port.

The active runtime port is written to:

```text
engine_runtime.json
```

This allows the dashboard to discover the currently active engine instance automatically.

---

# Configuration

Core engine configuration is located in:

```text
engine/config.py
```

---

## Important Configuration Values

| Setting | Description |
|---|---|
| `COLLECTION_INTERVAL_SEC` | Telemetry collection interval |
| `ALERT_CONSECUTIVE_COUNT` | Required sustained readings before alerting |
| `ALERT_COOLDOWN_SEC` | Minimum time between alerts |
| `BASELINE_MIN_SAMPLES` | Samples required before baseline activation |

---

## User Preferences

User-adjustable preferences are stored separately and persisted locally.

Examples include:
- CPU pressure thresholds
- memory thresholds
- disk pressure thresholds
- anomaly sensitivity
- safeguard process configuration

---

# Testing

Run the Python test suite:

```bash
pytest tests/ -v
```

---

# Static Analysis

SentraCore uses `ruff` for linting and static analysis.

Run:

```bash
ruff check engine/ tests/ --select=E9,F63,F7,F82
```

---

# Logging

The engine supports both console and packaged execution modes.

In packaged (`--noconsole`) environments:
- logging automatically falls back to file-based output
- runtime issues are recorded for diagnostics

---

# Development Notes

- The engine is designed to operate independently from the Flutter dashboard.
- Dashboard communication occurs entirely through local APIs and WebSockets.
- Most engine components are modular and can be extended independently.

---

# Platform Notes

## Windows
Windows currently provides the most complete telemetry support and packaging integration.

---

## Linux
Linux supports core monitoring and dashboard communication features. Some advanced process metrics may vary by distribution and permissions.

---

## macOS
macOS supports the core monitoring pipeline, though certain low-level telemetry values may differ from Windows behavior due to operating system limitations.

---

# Troubleshooting

## Port Already in Use

If the engine cannot bind to port `8740`:
- it will automatically search for another free port
- verify firewall settings if dashboard discovery fails

---

## Missing Dependencies

If startup fails due to missing packages:

```bash
pip install -r requirements.txt
```

Ensure the active virtual environment is enabled before installation.

---

## API Not Reachable

Verify:
- the engine process is running
- no firewall is blocking local connections
- the runtime port matches the dashboard connection target

---

# Stopping the Engine

To stop the engine:

- Press `Ctrl + C` in terminal mode
- or terminate the packaged process from the operating system