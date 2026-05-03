# Development Setup

This guide covers how to get the SentraCore development environment running on your local machine.

## Prerequisites

### Python Engine
- Python 3.11 or higher
- Git
- Windows OS (some `psutil` telemetry counters are Windows-specific)

### Flutter Dashboard
- Flutter SDK (stable channel, 3.x or higher)
- Visual Studio 2022 Community or higher
  - **Required Workload:** Desktop development with C++
  - **Required Components:** MSVC v142 build tools, C++ CMake tools for Windows, Windows 10/11 SDK
- Windows Developer Mode enabled

---

## Repository Structure

```
SentraCore/
├── engine/             # Python monitoring engine
│   ├── alerts/         # Alert Manager and RCA integration
│   ├── api/            # FastAPI REST and WebSocket server
│   ├── baseline/       # Adaptive baseline model
│   ├── buffer/         # Time-series ring buffers
│   ├── collector/      # psutil system telemetry collector
│   ├── events/         # System event logger
│   ├── intelligence/   # Trend, Anomaly, Prediction, Stability engines
│   ├── normalization/  # EMA-based metric normalizer
│   ├── process/        # Process impact tracker
│   └── stress/         # Multi-state stress engine
├── dashboard/          # Flutter Windows desktop UI
├── tests/              # Python unit tests
├── docs/               # Project documentation
├── scripts/            # Build automation scripts
└── installer/          # Inno Setup installer configuration
```

---

## Engine Setup

### 1. Create and Activate a Virtual Environment

```powershell
python -m venv .venv
.venv\Scripts\Activate
```

### 2. Install Dependencies

```powershell
pip install -r requirements.txt
```

### 3. Run the Engine

The engine must be started as a module from the repository root so that all internal imports resolve correctly:

```powershell
.venv\Scripts\python -m engine.main
```

The engine will start and expose:
- **REST API:** `http://localhost:8740/api/v1/`
- **WebSocket (live state):** `ws://localhost:8740/ws/live`

### 4. Run the Test Suite

```powershell
.venv\Scripts\python -m pytest tests/ -v
```

### 5. Run the Linter

SentraCore uses `ruff` for static analysis. Run it before submitting any pull request:

```powershell
.venv\Scripts\ruff check engine/ tests/ --select=E9,F63,F7,F82
```

---

## Dashboard Setup

### 1. Enable Windows Developer Mode

Flutter requires Windows Developer Mode to create necessary symlinks during the build.
1. Open **Windows Settings**.
2. Search for **Developer Mode**.
3. Toggle it to **On**.

### 2. Install Flutter Dependencies

```powershell
cd dashboard
flutter pub get
```

### 3. Run the Dashboard in Debug Mode

Ensure the Python Engine is running first, then:

```powershell
flutter run -d windows
```

### 4. Verify with Flutter Analyze

```powershell
flutter analyze
flutter test
```

---

## Development Tips

- Always start the Python Engine before launching the Flutter Dashboard.
- The engine's collection interval is configurable in `engine/config.py` via `COLLECTION_INTERVAL_SEC`.
- Alert thresholds (`ALERT_STRESS_THRESHOLD`, `ALERT_CONSECUTIVE_COUNT`, `ALERT_COOLDOWN_SEC`) are also in `engine/config.py`.
