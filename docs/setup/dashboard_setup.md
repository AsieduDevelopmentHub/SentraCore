# SentraCore Dashboard Setup

The SentraCore dashboard is a Flutter Windows desktop application that connects to the Python engine via WebSocket and REST API to display real-time system intelligence.

---

## Prerequisites

- Flutter SDK (stable channel, 3.x or higher)
- Visual Studio 2022 Community or higher
  - **Required Workload:** Desktop development with C++
  - **Required Components:** MSVC v142 build tools, C++ CMake tools for Windows, Windows 10/11 SDK
- Windows Developer Mode enabled

Run `flutter doctor` to verify your environment is fully configured. All items relevant to Windows desktop development should show a green checkmark.

---

## Enable Windows Developer Mode

Flutter requires Windows Developer Mode to create symlinks during the build process.

1. Open **Windows Settings**.
2. Search for **Developer Mode**.
3. Toggle **Developer Mode** to **On**.

---

## Installation and Running

### 1. Install Flutter Dependencies

```powershell
cd dashboard
flutter pub get
```

### 2. Start the Python Engine First

The dashboard requires the engine to be running before it can display data. In a separate terminal from the repository root:

```powershell
.venv\Scripts\python -m engine.main
```

### 3. Run the Dashboard in Debug Mode

```powershell
flutter run -d windows
```

The dashboard will automatically connect to `ws://localhost:8000/ws/live` and begin displaying live system data.

---

## Dashboard Panels

| Panel | Description |
|---|---|
| Stability Indicator | System Stability Index (1–100) with penalty breakdown |
| Resource Gauges | Smoothed CPU, Memory, and Disk I/O values with spike indicators |
| Prediction Panel | Degradation Risk Score and Time-to-Exhaustion countdowns |
| Root Cause Analysis Panel | Primary bottleneck, suspect process, and trigger event from last alert |
| Metric Charts | 60-second rolling history for CPU, Memory, and Stability Index |
| Process Table | Top processes ranked by sustained system impact |
| Event Timeline | Chronological list of recent system events |

---

## Verifying the Build

```powershell
flutter analyze
flutter test
```

Both should complete with no errors before any pull request is submitted.

---

## Building for Production

To compile a release build:

```powershell
flutter build windows --release
```

The executable and all required DLL files will be located in:
```
dashboard\build\windows\x64\runner\Release\
```

This entire folder must be provided to Inno Setup when compiling the installer. See [Building SentraCore](../architecture/building.md) for the full packaging guide.
