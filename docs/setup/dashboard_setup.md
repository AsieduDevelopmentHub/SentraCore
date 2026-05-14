# SentraCore Dashboard Setup

The SentraCore dashboard is a Flutter-based desktop application that provides real-time visibility into system behavior, predictive risk analysis, historical monitoring, process intelligence, and diagnostic insights.

The dashboard communicates with the local SentraCore engine through REST APIs and WebSockets to deliver continuously updated telemetry and intelligence data.

---

# Platform Support

| Platform | Support Status |
|---|---|
| Windows | Primary Support |
| Linux | Supported |
| macOS | Supported |

Windows currently provides the most complete packaging and deployment workflow.

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

Install the required Flutter desktop dependencies.

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

If desktop support is not already enabled:

```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

Verify configuration:

```bash
flutter doctor
```

---

# Installation

Navigate to the dashboard directory:

```bash
cd dashboard
```

Install dependencies:

```bash
flutter pub get
```

---

# Starting the SentraCore Engine

The dashboard requires the SentraCore engine to be running before live telemetry and diagnostics can be displayed.

From the repository root:

## Windows

```powershell
.venv\Scripts\python -m engine.main
```

---

## Linux / macOS

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

# Connection & Runtime Behavior

The dashboard automatically:

- discovers the active engine runtime port
- establishes WebSocket communication
- retrieves REST API data
- reconnects if the engine restarts
- synchronizes live telemetry and alert history

Default local endpoints:

```text
REST API:
http://localhost:8740/api/v1/

WebSocket:
ws://localhost:8740/ws/live
```

If the default port is unavailable, the engine dynamically selects another free port and exposes it through runtime discovery.

---

# Dashboard Features

| Feature | Description |
|---|---|
| System Stability Index | Unified system health and responsiveness scoring |
| Resource Monitoring | Real-time CPU, memory, and disk pressure analysis |
| Historical Logbook | Long-term telemetry and pressure history |
| Predictive Analysis | Degradation forecasting and risk estimation |
| Root Cause Analysis | Correlated slowdown explanations and diagnostics |
| Process Intelligence | Sustained process impact monitoring |
| Alerts & Diagnostics | Alert history, RCA summaries, and event tracking |
| Theme System | Light and dark mode support |
| Responsive UI | Adaptive desktop layouts and scalable panels |

---

# Development Validation

Before submitting changes, run analysis and tests:

```bash
flutter analyze
flutter test
```

---

# Building for Production

Generate release builds for the target platform.

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

For Windows packaging, the complete release output directory must be included during installer compilation.

See:

```text
docs/architecture/building.md
```

for packaging and release workflow details.

---

# Troubleshooting

## Dashboard Cannot Connect

Verify:
- the engine is running
- firewall rules are not blocking local communication
- dashboard and engine versions are compatible

---

## Flutter Build Issues

Run:

```bash
flutter doctor
```

and resolve any reported dependency or SDK issues.

---

## Missing Desktop Targets

Enable Flutter desktop support:

```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

---

# Notes

- The dashboard operates independently from the engine lifecycle.
- Runtime discovery and automatic reconnection are built into the communication layer.
- Some telemetry behavior may vary slightly between operating systems depending on available system APIs and permissions.