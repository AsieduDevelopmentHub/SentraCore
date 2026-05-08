# SentraCore Documentation

This directory contains the technical documentation for the SentraCore project, including setup guides, architecture references, development workflows, and packaging instructions.

---

# Setup Guides

| Guide | Description |
|---|---|
| [Development Setup](setup/development_setup.md) | Complete multi-platform development environment setup |
| [Engine Setup](setup/engine_setup.md) | Python engine installation and runtime guide |
| [Dashboard Setup](setup/dashboard_setup.md) | Flutter desktop dashboard setup and build guide |

---

# Architecture & Technical Reference

| Document | Description |
|---|---|
| [Intelligence Pipeline](architecture/intelligence_layer.md) | Detailed overview of the telemetry intelligence pipeline |
| [Building SentraCore](architecture/building.md) | Desktop build, packaging, and release workflow |

---

# Project Overview

SentraCore is a local system behavior intelligence platform that transforms raw system telemetry into explainable performance insights through:

- behavioral modeling
- anomaly detection
- predictive risk analysis
- root cause correlation
- real-time monitoring
- historical system analysis

The project is structured around a modular engine and desktop dashboard architecture.

---

# Core Components

| Component | Description |
|---|---|
| Engine | Python-based telemetry and intelligence service |
| Dashboard | Flutter desktop application |
| API Layer | Local REST and WebSocket communication |
| Intelligence Pipeline | Trend, anomaly, prediction, and correlation systems |
| Packaging System | Desktop build and installer workflow |

---

# Platform Support

| Platform | Status |
|---|---|
| Windows | Primary Support |
| Linux | Development Support |
| macOS | Development Support |

Windows currently provides the most complete packaging and deployment workflow.

---

# Development Scope

The project currently includes:

- real-time telemetry collection
- adaptive baseline learning
- anomaly detection
- predictive degradation analysis
- root cause analysis
- historical monitoring
- desktop notifications
- dashboard diagnostics
- desktop packaging workflow

---

# Documentation Structure

```text
docs/
├── setup/
│   ├── development_setup.md
│   ├── engine_setup.md
│   └── dashboard_setup.md
│
├── architecture/
│   ├── intelligence_layer.md
│   └── building.md
```

---

# Notes

- The documentation is designed for contributors, developers, and advanced users.
- Platform-specific behavior may vary depending on operating system capabilities.
- Additional documentation may be expanded as the project evolves.
