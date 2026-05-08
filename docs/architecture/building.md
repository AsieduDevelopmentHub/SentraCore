# Building SentraCore

This guide explains how to build the SentraCore engine, compile the Flutter dashboard, and package the application for desktop distribution.

The project is designed to support standalone deployment with a bundled local monitoring engine and desktop dashboard.

---

# Overview

SentraCore consists of two primary components:

| Component | Description |
|---|---|
| Engine | Python-based monitoring and intelligence service |
| Dashboard | Flutter desktop application |

These components are packaged together into a desktop installer for distribution.

---

# Prerequisites

## General Requirements

| Requirement | Verification |
|---|---|
| Python 3.11 or higher | `python --version` |
| Flutter SDK | `flutter --version` |
| Git | `git --version` |

---

# Windows Build Requirements

## Visual Studio

Install:
- Visual Studio 2022 Community Edition or higher

### Required Workload
- Desktop development with C++

### Required Components
- MSVC build tools
- C++ CMake tools
- Windows SDK

Verify setup:

```bash
flutter doctor
```

---

# Linux Build Requirements

Example dependencies for Ubuntu/Debian:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

---

# macOS Build Requirements

Install:
- Xcode Command Line Tools
- CocoaPods

```bash
xcode-select --install
sudo gem install cocoapods
```

---

# Python Packaging Requirements

Install PyInstaller inside the active virtual environment:

```bash
pip install pyinstaller
```

Verify installation:

```bash
pyinstaller --version
```

---

# Build Process

---

# Step 1 — Build the Python Engine

The engine is packaged as a standalone executable using PyInstaller.

Example build command:

```bash
pyinstaller engine.spec
```

Typical packaged output:

```text
dist/SentraCoreEngine/
```

or:

```text
dist/SentraCoreEngine.exe
```

depending on build configuration.

---

## Engine Packaging Notes

The packaged engine:
- runs as a background service
- exposes REST and WebSocket interfaces locally
- supports file-based logging in non-console environments
- includes required hidden imports for FastAPI and Uvicorn

Production builds commonly use:
- `--noconsole`
- optimized bundling
- application icons
- version metadata

---

# Step 2 — Build the Flutter Dashboard

Navigate to the dashboard directory:

```bash
cd dashboard
```

---

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

# Dashboard Build Output

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

# Packaging Considerations

Flutter desktop builds include:
- executable files
- runtime DLLs/frameworks
- asset bundles
- platform-specific dependencies

The complete release output directory should always be distributed together.

---

# Windows Installer Packaging

SentraCore uses Inno Setup for Windows installer generation.

---

## Inno Setup

Install:
- Inno Setup 6 or higher

Official website:

[Inno Setup](https://jrsoftware.org/isinfo.php?utm_source=chatgpt.com)

---

## Typical Installer Responsibilities

The installer may:
- copy engine and dashboard binaries
- create desktop and Start Menu shortcuts
- configure startup behavior
- register uninstall information
- launch the engine after installation
- clean up runtime files during uninstall

---

# Recommended Packaging Workflow

```text
1. Build Engine
2. Build Dashboard
3. Validate Release Builds
4. Package Installer
5. Test Clean Installation
6. Publish Release Assets
```

---

# Versioning

Version information should remain synchronized across:
- engine metadata
- dashboard application version
- installer version
- release artifacts

---

# Release Workflow

A typical release process includes:

1. Update version metadata
2. Build production artifacts
3. Validate installation behavior
4. Test dashboard-engine communication
5. Generate installer packages
6. Create tagged release builds
7. Publish release assets

---

# Production Validation Checklist

Before publishing a release, verify:

- engine starts successfully
- dashboard connects automatically
- live telemetry updates function correctly
- alerts and history load properly
- notifications operate correctly
- installer shortcuts work
- uninstall removes runtime artifacts cleanly

---

# Continuous Integration

SentraCore can be integrated into CI/CD pipelines for:

- linting
- automated testing
- desktop builds
- packaging validation
- release automation

Typical tooling:
- GitHub Actions
- pytest
- flutter test
- ruff
- PyInstaller
- Flutter build pipeline

---

# Build Notes

- Windows currently provides the most mature packaging workflow.
- Linux and macOS builds support desktop execution and development workflows.
- Some platform-specific packaging behaviors may vary depending on operating system requirements and distribution targets.

---

# Troubleshooting

## Flutter Build Issues

Run:

```bash
flutter doctor
```

Resolve any reported SDK or dependency issues.

---

## Missing Runtime Files

Ensure the entire Flutter release directory is distributed, not only the executable.

---

## Engine Startup Issues

Verify:
- required Python dependencies are included
- hidden imports are configured correctly
- firewall settings are not blocking local communication

---

## Installer Launch Problems

Check:
- installation paths
- bundled runtime files
- startup permissions
- application icons and resource paths

---

# Summary

SentraCore is structured for modular desktop deployment:

- Python handles telemetry collection and intelligence processing
- Flutter provides the real-time desktop experience
- platform-specific packaging systems distribute the application as a standalone product

This architecture allows the engine and dashboard to evolve independently while remaining tightly integrated during runtime.