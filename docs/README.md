# SentraCore Documentation

Central documentation hub for **SentraCore** — a local system behavior intelligence platform designed to transform system telemetry into explainable operational insights through analytics, prediction, and real-time observability.

This documentation provides architecture references, setup instructions, development workflows, and deployment guidance for contributors, maintainers, and advanced users.

For product overview, capabilities, and repository onboarding, begin with the [main repository README](../README.md).

---

## Documentation Overview

This directory contains technical resources for understanding, building, extending, and operating SentraCore.

### Contents

- Development and environment setup
- Engine runtime configuration
- Dashboard build instructions
- Architecture references
- Intelligence pipeline internals
- Persistence and storage behavior
- Packaging and release workflows

---

## Repository Structure

The SentraCore repository is organized into modular system boundaries.

| Path | Responsibility |
|---|---|
| `engine/` | Telemetry engine, intelligence processing, runtime services, and local API |
| `dashboard/` | Flutter desktop application and user interface |
| `docs/` | Technical documentation and implementation references |
| `installer/` | Windows packaging and installation definitions |
| `pages/` | Static website and public documentation |
| `assets/` | Shared frontend assets used across documentation pages |
| `tests/` | Automated testing for engine and API components |

---

## Setup Guides

Use these guides to configure a local development environment.

| Guide | Description |
|---|---|
| [Development Setup](setup/development_setup.md) | Complete environment setup for local development |
| [Engine Setup](setup/engine_setup.md) | Engine installation, configuration, and execution |
| [Dashboard Setup](setup/dashboard_setup.md) | Flutter dashboard development and build workflow |

---

## Architecture & Technical Reference

Detailed implementation references for internal platform components.

| Document | Description |
|---|---|
| [Intelligence Pipeline](architecture/intelligence_layer.md) | Telemetry ingestion, analysis, prediction, and insight generation |
| [Persistence Architecture](architecture/persistence.md) | Storage layout for preferences, baselines, logs, and history |
| [Hardware Health Monitoring](architecture/hardware_health.md) | CPU, memory, SMART monitoring, and health classification |
| [Storage Analysis & Cleanup](architecture/storage_scan.md) | Storage scanning, cleanup rules, and scan safety mechanisms |
| [Build & Packaging](architecture/building.md) | Desktop packaging, installer generation, and release workflow |

---

## Project Overview

SentraCore is an **intelligence-driven desktop observability platform** that converts raw telemetry into actionable system understanding.

Core platform capabilities include:

- Behavioral modeling
- Performance intelligence
- Real-time monitoring
- Anomaly detection
- Predictive risk analysis
- Root cause correlation
- Historical trend analysis

The platform follows a **modular engine + dashboard architecture** to separate intelligence processing from user interaction.

---

## System Components

| Component | Description |
|---|---|
| Engine | Python runtime responsible for telemetry and intelligence |
| Dashboard | Flutter-based desktop interface |
| API Layer | Local REST and WebSocket communication |
| Intelligence Layer | Detection, prediction, and correlation engine |
| Packaging Layer | Build and installer workflow |

---

## Supported Platforms

| Platform | Support Level |
|---|---|
| Windows | Full Support |
| Linux | Development Support |
| macOS | Development Support |

> Windows currently provides the most complete installation and packaging experience.

---

## Development Scope

Current platform capabilities include:

- Real-time telemetry collection
- Adaptive baseline learning
- Behavioral analysis
- Anomaly detection
- Predictive degradation analysis
- Root cause investigation
- Historical system monitoring
- Desktop notifications
- Diagnostic dashboards
- Desktop packaging workflow

---

## Documentation Layout

```text
docs/
│
├── setup/
│   ├── development_setup.md
│   ├── engine_setup.md
│   └── dashboard_setup.md
│
├── architecture/
│   ├── intelligence_layer.md
│   ├── persistence.md
│   ├── hardware_health.md
│   ├── storage_scan.md
│   └── building.md
│
└── README.md
```

---

## Typical Development Workflow

### 1. Prepare Environment

Create and activate a Python virtual environment.

Install engine dependencies.

See:

```text
setup/development_setup.md
```

---

### 2. Start Engine

Launch the telemetry engine.

```bash
python -m engine.main
```

Or use the documented project entrypoint.

---

### 3. Launch Dashboard

Open a second terminal.

Run the Flutter dashboard against the local engine.

See:

```text
setup/dashboard_setup.md
```

---

### 4. Run Validation

Execute automated tests before committing changes.

```bash
pytest
```

---

## Contributing Notes

Before opening pull requests:

- Follow documented setup procedures
- Validate local builds
- Run test suites
- Keep architecture documentation updated
- Maintain cross-platform compatibility where applicable

---

## Documentation Principles

SentraCore documentation is designed around:

- Developer onboarding
- Maintainable architecture
- Operational clarity
- Reproducible workflows
- Long-term maintainability

---

## Additional Notes

- Platform behavior may vary across operating systems
- Documentation evolves alongside implementation
- Architecture documents are considered the source of technical truth

---

<div align="center">

### SentraCore Documentation

Build • Understand • Extend

</div>