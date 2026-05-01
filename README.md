# SentraCore

SentraCore is a local system behavior intelligence layer that continuously analyzes time-based system telemetry to understand performance behavior, estimate degradation risk, and provide explainable root-cause insights with safe optimization recommendations.

It is designed to go beyond traditional monitoring tools by interpreting system behavior over time rather than simply displaying real-time system metrics.

---

## Overview

Most system tools focus on snapshots of current resource usage. SentraCore focuses on behavior over time.

It answers three key questions:

- What is happening in the system?
- Why is it happening?
- What is likely to happen next in terms of performance impact?

SentraCore does not replace tools like Task Manager. Instead, it enhances understanding by providing behavioral intelligence and explanation layers on top of raw system data.

---

## Core Capabilities

### System Telemetry Collection
Collects real-time system data including:
- CPU usage trends
- Memory usage and paging behavior
- Disk activity and latency signals
- Process-level resource usage
- System events and state changes

---

### Behavioral Modeling
Builds a baseline model of normal system behavior per machine using:
- Moving averages
- Trend analysis
- Statistical deviation tracking
- Time-windowed behavior patterns

---

### Anomaly Detection (Probabilistic)
Detects deviations from normal system behavior using a risk-based model rather than deterministic rules.

Outputs a system degradation risk score based on:
- Sustained resource pressure
- Behavioral deviation from baseline
- Rate of change in system metrics
- Multi-resource saturation patterns

---

### Correlation and Root Cause Analysis
Identifies likely contributors to system performance degradation by analyzing:
- Temporal relationships between system events and performance changes
- Resource contention across CPU, memory, and disk
- Process behavior patterns over time

Outputs explainable insights rather than raw process rankings.

---

### Responsiveness Modeling
Estimates user-perceived system performance impact by analyzing:
- Disk latency patterns
- CPU scheduling pressure
- Memory paging frequency
- Context switching behavior

This translates system-level metrics into real-world usability impact such as lag or slow response.

---

### Process Intelligence
Processes are analyzed based on:
- Sustained resource impact over time
- Historical correlation with system slowdown events
- Contribution to system-wide pressure

Processes are ranked by system impact rather than instantaneous usage.

---

### Baseline Learning
SentraCore adapts to each machine by learning normal behavior patterns over time, including:
- Idle behavior
- Active workload patterns
- Time-of-day usage trends
- System-specific performance characteristics

---

### Event Correlation
Tracks system events such as:
- Application launches and closures
- Background service execution
- System updates
- Disk indexing and maintenance operations

These events improve accuracy of behavioral and correlation analysis.

---

### Safety-First Optimization Layer
SentraCore provides system optimization suggestions with strict safety constraints.

Three levels of intervention:

- Recommendation Only (default)
- User-approved actions
- Safe automated actions (restricted to non-critical processes)

No forced termination of critical system processes is performed.

---

## System Architecture

Flutter Dashboard ↓ (WebSocket / Local API) SentraCore Engine (Python Core) ├── Telemetry Collector ├── Time-Series Storage Layer ├── Behavior Modeling Engine ├── Anomaly Detection Engine ├── Correlation Engine ├── Decision & Safety Controller ↓ Operating System (CPU, RAM, Disk, Processes)

---

## Data Model (Conceptual)

SentraCore operates on structured time-series data:

- Timestamped CPU usage
- Memory consumption trends
- Disk activity metrics
- Process-level statistics
- System event logs

This enables historical analysis rather than snapshot-based monitoring.

---

## System Output Example

Instead of raw metrics, SentraCore produces structured insights:

System State: Degrading  
Primary Pressure: Memory and Disk I/O  
Risk Level: 72% (Moderate)  
User Impact: Application lag likely during multitasking  
Likely Contributors: Chrome processes, background update service, increased disk queue activity  

---

## Technology Stack

- Python (core engine)
- psutil (system telemetry)
- FastAPI or local API layer (communication)
- WebSockets (real-time updates)
- Flutter Desktop (dashboard UI)
- SQLite or lightweight time-series storage (optional)

---

## Project Philosophy

SentraCore is built around five principles:

1. Observation — collect raw system data
2. Behavioral Modeling — understand normal system behavior
3. Anomaly Detection — detect deviation patterns
4. Correlation Analysis — identify likely contributing factors
5. User Impact Translation — convert system data into human-readable insights

---

## Positioning

SentraCore belongs to a new category of system software:

System Behavior Intelligence Layer

It differs from traditional tools:

- Task Manager: reactive snapshots
- Process Explorer: manual deep inspection
- Monitoring tools: infrastructure-focused

SentraCore focuses on:
- time-based behavior understanding
- probabilistic performance degradation detection
- explainable system insights
- user-centric performance interpretation

---

## Current Status

This project is in architecture and design phase, transitioning toward MVP implementation.

---

## Future Roadmap

- Core telemetry collector implementation
- Baseline learning engine
- Anomaly detection model
- Process correlation system
- Flutter dashboard integration
- Optimization recommendation engine
- Optional automation layer (user-controlled)

---

## License

To be defined.

---

## Author

SentraCore is designed and developed as a system intelligence research and engineering project focused on next-generation local system understanding.
