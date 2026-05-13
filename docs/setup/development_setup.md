# Development Setup

This guide explains how to configure a local SentraCore development environment across Windows, Linux, and macOS. Use it together with the [documentation index](../README.md) for architecture and packaging context.

---

# Supported Platforms

| Platform | Status |
|---|---|
| Windows | Primary Development Target |
| Linux | Supported for Development |
| macOS | Supported for Development |

Some telemetry capabilities may vary slightly between operating systems due to platform-specific system APIs exposed through `psutil`.

---

# Prerequisites

## General Requirements

- Python 3.11 or higher
- Git

---

# Flutter Dashboard Requirements

## Flutter SDK
- Flutter SDK (stable channel, version 3.x or higher)

Verify installation:

```bash
flutter doctor
```

---

## Windows Requirements

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

## Linux Requirements

Install required development packages for Flutter desktop support.

Example (Ubuntu/Debian):

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

---

## macOS Requirements

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

# Repository Structure

```text
SentraCore/
├── engine/             # Python monitoring and intelligence engine
├── dashboard/          # Flutter desktop dashboard
├── tests/              # Python test suite
├── docs/               # Project documentation
├── scripts/            # Build and automation scripts
└── installer/          # Installer configuration
```

---

# Engine Setup

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

## 2. Activate the Environment

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

## 4. Start the Engine

Run the engine from the repository root:

### Windows

```powershell
.venv\Scripts\python -m engine.main
```

### Linux / macOS

```bash
python -m engine.main
```

The engine exposes:

- REST API  
  `http://localhost:8740/api/v1/`

- WebSocket Endpoint  
  `ws://localhost:8740/ws/live`

---

## 5. Run Tests

```bash
pytest tests/ -v
```

---

## 6. Run Static Analysis

SentraCore uses `ruff` for Python linting and static analysis.

```bash
ruff check engine/ tests/ --select=E9,F63,F7,F82
```

---

# Dashboard Setup

## 1. Install Flutter Dependencies

```bash
cd dashboard
flutter pub get
```

---

## 2. Run the Dashboard

Ensure the Python engine is already running.

### Windows

```powershell
flutter run -d windows
```

### Linux

```bash
flutter run -d linux
```

### macOS

```bash
flutter run -d macos
```

---

## 3. Run Flutter Validation

```bash
flutter analyze
flutter test
```

---

# Development Notes

- Start the Python engine before launching the Flutter dashboard.
- Engine configuration values are located in:

```text
engine/config.py
```

Configurable settings include:
- collection interval
- alert thresholds
- cooldown durations
- anomaly sensitivity
- safeguard behavior

---

# Troubleshooting

## Flutter Desktop Support Not Enabled

Verify Flutter desktop support:

```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

Then verify using:

```bash
flutter doctor
```

---

## Dashboard Cannot Connect

Ensure:
- the engine is running
- local firewall rules are not blocking connections
- the dashboard and engine versions are compatible

---

## Port Already in Use

If port `8740` is occupied:
- stop the conflicting process
- or update the configured engine port before restarting

---

# Platform Notes

- Windows currently provides the most complete telemetry support.
- Linux and macOS support core monitoring and dashboard functionality.
- Some advanced process or system metrics may behave differently across operating systems due to underlying OS APIs.