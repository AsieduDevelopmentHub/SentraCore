"""
SentraCore — Central Configuration.

All tunable constants and system-wide settings are defined here.
Modules import from this file to ensure consistent behavior across the engine.
"""

from __future__ import annotations

import os
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# Root directory of the app package
APP_DIR = Path(__file__).parent


def _writable_datastore_dir() -> Path:
    """
    Resolve a writable datastore directory.

    - Dev mode: using `engine/datastore/` is fine.
    - Installed mode (e.g. under Program Files): we must not write into the install dir.

    Order:
    1) SENTRACORE_DATA_DIR (explicit override)
    2) Local package datastore if it can be created/written
    3) %LOCALAPPDATA%/SentraCore/datastore (Windows)
    4) ~/.local/share/SentraCore/datastore (fallback)
    """
    override = os.environ.get("SENTRACORE_DATA_DIR")
    if override:
        return Path(override)

    local = APP_DIR / "datastore"
    try:
        local.mkdir(parents=True, exist_ok=True)
        test = local / ".write_test"
        test.write_text("ok", encoding="utf-8")
        test.unlink(missing_ok=True)
        return local
    except OSError:
        pass

    local_appdata = os.environ.get("LOCALAPPDATA")
    if local_appdata:
        return Path(local_appdata) / "SentraCore" / "datastore"

    return Path.home() / ".local" / "share" / "SentraCore" / "datastore"


# Persistent data storage directory (writable)
DATASTORE_DIR = _writable_datastore_dir()

# Baseline model persistence file
BASELINE_FILE = DATASTORE_DIR / "baseline.json"

# ---------------------------------------------------------------------------
# Collection Engine
# ---------------------------------------------------------------------------

# How often the collector samples system telemetry (seconds).
# You can override in installed builds via SENTRACORE_COLLECTION_INTERVAL_SEC.
try:
    COLLECTION_INTERVAL_SEC: float = float(
        os.environ.get("SENTRACORE_COLLECTION_INTERVAL_SEC", "2.0")
    )
except ValueError:
    COLLECTION_INTERVAL_SEC = 2.0

# Maximum number of processes to capture per snapshot (top-N by CPU+memory impact).
# Process enumeration is one of the most expensive operations; keep this small.
try:
    MAX_PROCESSES_PER_SNAPSHOT: int = int(
        os.environ.get("SENTRACORE_MAX_PROCESSES_PER_SNAPSHOT", "15")
    )
except ValueError:
    MAX_PROCESSES_PER_SNAPSHOT = 15

# Only refresh the per-process list every N collection cycles. Between refreshes,
# the engine reuses the last computed top-N list. This cuts CPU drastically while
# keeping system totals (CPU/mem/disk) at full frequency.
try:
    PROCESS_SNAPSHOT_EVERY_N: int = max(
        1, int(os.environ.get("SENTRACORE_PROCESS_SNAPSHOT_EVERY_N", "5"))
    )
except ValueError:
    PROCESS_SNAPSHOT_EVERY_N = 5

# ---------------------------------------------------------------------------
# Time-Series Buffers
# ---------------------------------------------------------------------------

# Short window: real-time behavior analysis (default 5 minutes)
SHORT_WINDOW_SEC: int = 300

# Long window: behavioral trend analysis (default 60 minutes)
LONG_WINDOW_SEC: int = 3600

# Computed buffer sizes based on collection interval
SHORT_BUFFER_SIZE: int = int(SHORT_WINDOW_SEC / COLLECTION_INTERVAL_SEC)  # 150
LONG_BUFFER_SIZE: int = int(LONG_WINDOW_SEC / COLLECTION_INTERVAL_SEC)  # 1800

# ---------------------------------------------------------------------------
# Data Normalization
# ---------------------------------------------------------------------------

# Exponential Moving Average smoothing factor (0 < α ≤ 1)
# Lower = smoother, higher = more responsive
EMA_ALPHA: float = 0.3

# Minimum consecutive elevated readings to count as a real spike (not noise)
MIN_SPIKE_READINGS: int = 2

# ---------------------------------------------------------------------------
# Stress Engine
# ---------------------------------------------------------------------------

# Stress level thresholds
STRESS_LOW_THRESHOLD: int = 30
STRESS_MODERATE_THRESHOLD: int = 60
STRESS_HIGH_THRESHOLD: int = 85

# Default signal weights (adaptive engine may adjust these)
STRESS_WEIGHT_CPU: float = 0.40
STRESS_WEIGHT_MEMORY: float = 0.35
STRESS_WEIGHT_DISK: float = 0.25

# ---------------------------------------------------------------------------
# Baseline Model
# ---------------------------------------------------------------------------

# Minimum samples before baseline is considered valid
BASELINE_MIN_SAMPLES: int = 60  # ~2 minutes of data at 2s interval

# Standard deviation multiplier for deviation detection
BASELINE_DEVIATION_SIGMA: float = 2.0

# How often to persist baseline to disk (in collection cycles)
BASELINE_PERSIST_INTERVAL: int = 150  # Every ~5 minutes

# ---------------------------------------------------------------------------
# Process Intelligence
# ---------------------------------------------------------------------------

# Number of top processes to track and return
TOP_PROCESSES_COUNT: int = 10

# Sliding window size for process impact calculation (in samples)
PROCESS_WINDOW_SIZE: int = 30  # ~1 minute of data

# Drop a PID from the tracker after this many snapshots without appearing in
# the collector's top-N process list (exited, or fell out of the top list).
PROCESS_MISS_SNAPSHOTS_BEFORE_PRUNE: int = 1

# ---------------------------------------------------------------------------
# Event Logger
# ---------------------------------------------------------------------------

# Maximum events stored in the ring buffer
MAX_EVENTS: int = 1000

# CPU spike threshold (percentage)
EVENT_CPU_SPIKE_THRESHOLD: float = 85.0

# Memory pressure threshold (percentage)
EVENT_MEMORY_PRESSURE_THRESHOLD: float = 85.0

# Disk activity spike threshold (ops/sec — calibrated during baseline)
EVENT_DISK_SPIKE_THRESHOLD: float = 500.0

# ---------------------------------------------------------------------------
# Alert Manager
# ---------------------------------------------------------------------------

# Resource alert thresholds (CPU %, memory %, disk pressure 0–100) are user-tunable
# via user_preferences.json / GET|PUT /api/v1/preferences (see engine/user_preferences.py).

# Number of consecutive high-stress readings before alert fires
ALERT_CONSECUTIVE_COUNT: int = 5  # 5 readings × 2s = 10 seconds

# Cooldown period after an alert fires (seconds)
ALERT_COOLDOWN_SEC: float = 60.0

# ---------------------------------------------------------------------------
# API Server
# ---------------------------------------------------------------------------

# WebSocket broadcast interval (seconds) — matches collection interval
WS_BROADCAST_INTERVAL: float = COLLECTION_INTERVAL_SEC
