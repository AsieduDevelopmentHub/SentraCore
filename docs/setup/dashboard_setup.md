# SentraCore Dashboard Setup

The SentraCore dashboard is a Flutter desktop application that connects to the local Python engine through REST APIs and WebSockets to display real-time system intelligence, alerts, historical monitoring data, and diagnostic insights.

The dashboard supports:
- Windows
- Linux
- macOS

Windows currently provides the most complete production packaging support.

---

# Prerequisites

## Flutter SDK

- Flutter SDK (stable channel, version 3.x or higher)

Verify installation:

```bash
flutter doctor
```

All desktop-related checks should pass before development begins.

---

# Platform Requirements

## Windows

### Required Software
- Visual Studio 2022 Community Edition or higher

### Required Workload
- Desktop development with C++

### Required Components
- MSVC build tools
- C++ CMake tools for Windows
- Windows 10/11 SDK

### Additional Requirement
- Windows Developer Mode enabled

---

## Linux

Install required Flutter desktop dependencies.

Example (Ubuntu/Debian):

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

---

## macOS

### Required Software
- Xcode Command Line Tools
- CocoaPods

Install Xcode tools:

```bash
xcode-select --install
```

Install CocoaPods:

```bash
sudo gem install cocoapods
```

---

# Enable Desktop Support

If desktop support is not enabled in Flutter:

```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

Verify again:

```bash
flutter doctor
```

---

# Installation

Navigate to the dashboard directory:

```bash
cd dashboard
```

Install Flutter dependencies:

```bash
flutter pub get
```

---

# Starting the Engine

The dashboard requires the SentraCore engine to be running before live data can be displayed.

From the repository root:

### Windows

```powershell
.venv\Scripts\python -m engine.main
```

### Linux / macOS

```bash
python -m engine.main
```

---

# Running the Dashboard

## Windows

```powershell
flutter run -d windows
```

---

## Linux

```bash
flutter run -d linux
```

---

## macOS

```bash
flutter run -d macos
```

---

# Connection Behavior

The dashboard automatically:

- discovers the active engine runtime port
- connects to the local WebSocket stream
- retrieves REST API data
- reconnects automatically if the engine restarts

Default engine endpoints:

```text
REST API:
http://localhost:8740/api/v1/

WebSocket:
ws://localhost:8740/ws/live
```

If port `8740` is unavailable, the engine dynamically selects another free port and exposes it through runtime discovery.

---

# Dashboard Features

| Feature | Description |
|---|---|
| System Stability Index | Unified system health scoring |
| Resource Monitoring | CPU, memory, and disk pressure tracking |
| Historical Logbook | Long-term system history visualization |
| Predictive Analysis | Degradation risk and forecasting |
| Root Cause Analysis | Correlated slowdown explanations |
| Process Intelligence | Sustained process impact ranking |
| Alerts & Diagnostics | Real-time alerts and RCA history |
| Theme System | Light and dark mode support |
| Responsive Layout | Adaptive desktop layout behavior |

---

# Development Validation

Run Flutter analysis and tests before submitting changes.

```bash
flutter analyze
flutter test
```

---

# Building for Production

Generate a release build:

## Windows

```powershell
flutter build windows --release
```

---

## Linux

```bash
flutter build linux --release
```

---

## macOS

```bash
flutter build macos --release
```

---

# Build Output Locations

## Windows

```text
build/windows/x64/runner/Release/
```

---

## Linux

```text
build/linux/x64/release/bundle/
```

---

## macOS

```text
build/macos/Build/Products/Release/
```

---

# Packaging Notes

For Windows installer packaging, the full release output directory must be included during Inno Setup compilation.

See:

```text
docs/architecture/building.md
```

for complete packaging and distribution instructions.

---

# Troubleshooting

## Dashboard Cannot Connect

Verify:
- the engine is running
- firewall rules are not blocking local connections
- engine and dashboard versions are compatible

---

## Flutter Build Fails

Run:

```bash
flutter doctor
```

and resolve any missing dependencies or SDK issues.

---

## Missing Desktop Targets

Enable desktop support using:

```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

---

# Notes

- The dashboard is designed to operate independently from the engine process lifecycle.
- Automatic reconnection and runtime discovery are built into the connection layer.
- Some telemetry behavior may vary slightly across operating systems depending on available system APIs.