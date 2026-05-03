# SentraCore Engine Setup

The SentraCore engine is a headless Python application that collects system telemetry, processes it through the intelligence pipeline, and serves the results via a local REST API and WebSocket.

---

## Prerequisites

- Python 3.11 or higher
- Windows OS (some `psutil` telemetry counters are Windows-specific)
- Git

---

## Installation

From the repository root:

### 1. Create a Virtual Environment

```powershell
python -m venv .venv
```

### 2. Activate the Virtual Environment

```powershell
.venv\Scripts\Activate
```

### 3. Install Dependencies

```powershell
pip install -r requirements.txt
```

---

## Running the Engine

The engine must be run as a module from the root directory so that internal package imports resolve correctly:

```powershell
.venv\Scripts\python -m engine.main
```

On startup, the engine will:
- Start the `uvicorn` API server in a background thread.
- Begin the telemetry collection loop.
- Log periodic status updates to the console.

**Available endpoints once running:**

| Endpoint | Description |
|---|---|
| `GET http://localhost:8740/api/v1/status` | Full current system state snapshot |
| `GET http://localhost:8740/api/v1/processes` | Top processes by sustained impact |
| `GET http://localhost:8740/api/v1/events` | Recent system events |
| `GET http://localhost:8740/api/v1/alerts` | Alert history with Root Cause Analysis |
| `WS ws://localhost:8740/ws/live` | Real-time state broadcast (WebSocket) |

---

## Configuration

Key constants are configurable in `engine/config.py`:

| Constant | Default | Description |
|---|---|---|
| `COLLECTION_INTERVAL_SEC` | `2` | How frequently telemetry is sampled |
| `ALERT_STRESS_THRESHOLD` | `70.0` | Stress score required to trigger an alert |
| `ALERT_CONSECUTIVE_COUNT` | `3` | Consecutive high readings before alerting |
| `ALERT_COOLDOWN_SEC` | `60.0` | Minimum time between consecutive alerts |
| `BASELINE_MIN_SAMPLES` | `30` | Samples required before baseline is considered ready |

---

## Running Tests

```powershell
.venv\Scripts\python -m pytest tests/ -v
```

## Running the Linter

```powershell
.venv\Scripts\ruff check engine/ tests/ --select=E9,F63,F7,F82
```
