# SentraCore Roadmap (MVP → Production-Ready Path)

## Overview

SentraCore is a local system behavior intelligence layer that evolves from a lightweight monitoring engine into a full system intelligence product capable of behavioral understanding, root-cause analysis, and probabilistic performance risk estimation.

This roadmap defines a structured path from MVP to production-ready system without premature complexity.

---

# 🟢 PHASE 1 — CORE MONITORING ENGINE (MVP FOUNDATION)

## Goal
Build a stable, low-overhead system monitoring engine with basic behavioral awareness.

This phase focuses on reliable telemetry collection and clean signal preparation.

---

## Core Modules

### 1. System Collector
Collect real-time system telemetry using `psutil`:
- CPU usage
- Memory usage
- Disk activity
- Process list snapshot
- Per-process CPU and memory usage

---

### 2. Dual Time-Series Buffer (Critical)
Maintain structured short-term and long-term system history:

- Short window: 2–5 minutes (real-time behavior)
- Long window: 15–60 minutes (behavioral trends)

Stored using efficient in-memory buffers (deque or equivalent).

---

### 3. Data Normalization Layer
Before analysis:
- Smooth spikes
- Reduce noise
- Normalize inconsistent sampling intervals

---

### 4. Basic Stress Engine (Improved MVP Version)

Instead of static weighting, use signal-based scoring:

- CPU trend intensity
- Memory pressure ratio (used vs available)
- Disk activity rate (not only usage percentage)

Output:
- System Stress Score (0–100)

---

### 5. Minimal Baseline Model (Lightweight MVP Version)

Track basic system norms:
- Idle CPU range
- Average memory usage
- Normal disk activity baseline

Used only for simple deviation detection.

---

### 6. Process Intelligence (MVP Level)

Track:
- Top CPU consumers (sustained usage)
- Top memory consumers
- Resource usage delta over time

Avoid snapshot-only ranking.

---

### 7. Event Logging Layer (Light Version)

Capture system events:
- process start/stop
- CPU spike detection
- memory pressure events
- disk activity spikes

Used later for correlation engine.

---

### 8. Basic Alert System

Trigger conditions:
- sustained high stress (not instant spike)
- cooldown to prevent spam alerts

Output:
- warning popup
- top contributing processes

---

## Deliverable
- Working Python system monitor
- Stable real-time loop
- Clean telemetry pipeline
- Basic alerting system

---

# 🟡 PHASE 2 — BEHAVIORAL INTELLIGENCE LAYER

## Goal
Transform raw monitoring into adaptive system behavior understanding.

---

## Core Features

### 1. Full Baseline Learning System
Per-machine adaptive modeling:
- normal CPU behavior
- memory usage patterns
- disk activity behavior
- time-of-day usage patterns

---

### 2. Anomaly Detection Engine
Detect deviations from baseline using:
- statistical deviation (z-score style)
- sustained abnormal patterns
- trend divergence

Output:
- behavioral anomaly state (not binary alerts)

---

### 3. Trend Analysis Engine
- slope detection (CPU/RAM growth trends)
- volatility measurement
- early warning signals

---

### 4. Improved Stress Model (Multi-State)

Break stress into:
- short-term pressure
- long-term pressure
- volatility score

Combine into final system state.

---

## Deliverable
- adaptive system behavior model
- reduced false alerts
- baseline-aware intelligence layer

---

# 🔵 PHASE 3 — CORRELATION & ROOT CAUSE ENGINE

## Goal
Enable system explanation: “Why is my system slow?”

---

## Core Features

### 1. Event Timeline Engine
Build ordered system timeline:
- CPU spikes
- memory pressure changes
- disk queue events
- process activity changes

---

### 2. Correlation Engine
Analyze relationships between:
- processes and CPU spikes
- services and disk saturation
- memory pressure and paging activity

Uses:
- time-window alignment
- correlation scoring
- weighted dependency mapping

---

### 3. Root Cause Ranking System

Output:
- ranked list of likely contributors
- probability-based attribution (not absolute blame)

Example:
- Chrome: 55%
- Background update service: 30%
- Indexing service: 15%

---

## Deliverable
- explainable system slowdown engine
- correlation-based diagnostics

---

# 🟣 PHASE 4 — PREDICTION & RISK ENGINE

## Goal
Shift from reactive analysis to probabilistic forecasting.

---

## Core Features

### 1. Probabilistic Risk Scoring
Replace deterministic prediction with:
- degradation probability score
- confidence-based estimation

---

### 2. Trend Forecasting
- CPU slope projection
- memory growth prediction
- disk saturation forecasting

---

### 3. System Stability Index
Multi-dimensional model:
- compute pressure
- memory pressure
- I/O pressure
- responsiveness index

---

## Deliverable
- early warning system
- predictive (non-deterministic) alerts

---

# 🟠 PHASE 5 — FLUTTER DASHBOARD SYSTEM

## Goal
Build full user-facing system intelligence interface.

---

## Core Features

- real-time system health dashboard
- stress visualization
- process intelligence view
- root cause explanation panel
- event timeline visualization
- system stability index display

---

## Architecture

Python Engine → WebSocket / Local API → Flutter UI

Define API contract before UI development.

---

## Deliverable
- desktop application (Windows first)
- real-time monitoring dashboard
- system intelligence UI

---

# 🔴 PHASE 6 — PRODUCTIZATION LAYER

## Goal
Convert system into installable, persistent software.

---

## Core Features

### 1. Background Service Mode
- auto-start on boot
- low CPU overhead operation

---

### 2. Executable Packaging
- PyInstaller-based build
- single executable output

---

### 3. Installer System
- Inno Setup installer
- desktop shortcuts
- uninstall support

---

### 4. Optional Auto-Update System
- version checking
- safe update mechanism

---

## Deliverable
- SentraCore.exe
- installer package
- production-ready desktop application

---

# 🧠 FINAL SYSTEM EVOLUTION PATH

MVP (Monitoring Engine)
→ Behavioral Intelligence Layer
→ Root Cause Engine
→ Prediction Engine
→ UI Product Layer
→ Full Production Software

---

# 🧭 KEY DESIGN RULES ACROSS ALL PHASES

- Avoid over-engineering early
- Prefer probabilistic outputs over deterministic claims
- Always prioritize user-impact interpretation
- Keep system explainability at the center
- Maintain modular architecture for scalability

---

# END STATE

SentraCore evolves into:

A local system behavior intelligence platform that continuously interprets system performance, detects anomalies, explains causes, and provides safe optimization guidance in real time.
