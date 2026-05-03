# SentraCore Documentation

This directory contains all technical documentation for the SentraCore project.

---

## Setup Guides

| Guide | Description |
|---|---|
| [Development Setup](setup/development_setup.md) | Complete local development environment guide for both the engine and dashboard |
| [Engine Setup](setup/engine_setup.md) | Python engine installation reference |
| [Dashboard Setup](setup/dashboard_setup.md) | Flutter dashboard setup reference |

---

## Architecture & Technical Reference

| Document | Description |
|---|---|
| [Intelligence Pipeline](architecture/intelligence_layer.md) | Deep dive into all 10 processing stages from raw telemetry to Root Cause Analysis |
| [Building SentraCore](architecture/building.md) | How to produce standalone executables and compile the Inno Setup installer |

---

## Project Status

All six development phases are complete:

| Phase | Scope |
|---|---|
| Phase 1 | Core Telemetry Engine — psutil collection, normalizer, buffers, alert system |
| Phase 2 | Behavioral Intelligence — baseline learning, anomaly detection, trend analysis |
| Phase 3 | Correlation & RCA Engine — root cause analysis, event correlation, alert enrichment |
| Phase 4 | Prediction & Risk Engine — ETA forecasting, risk scoring, stability index |
| Phase 5 | Flutter Dashboard — stability indicator, prediction panel, RCA panel, charts |
| Phase 6 | Productization — PyInstaller packaging, Flutter build, Inno Setup installer |
