"""
SentraCore — Central Configuration.

All tunable constants and system-wide settings are defined here.
Modules import from this file to ensure consistent behavior across the engine.
"""

from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# Root directory of the app package
APP_DIR = Path(__file__).parent

# Persistent data storage directory
DATASTORE_DIR = APP_DIR / "datastore"

# Baseline model persistence file
BASELINE_FILE = DATASTORE_DIR / "baseline.json"

# ---------------------------------------------------------------------------
# Collection Engine
# ---------------------------------------------------------------------------

# How often the collector samples system telemetry (seconds)
COLLECTION_INTERVAL_SEC: float = 2.0

# Maximum number of processes to capture per snapshot
MAX_PROCESSES_PER_SNAPSHOT: int = 30

# ---------------------------------------------------------------------------
# Time-Series Buffers
# ---------------------------------------------------------------------------

# Short window: real-time behavior analysis (default 5 minutes)
SHORT_WINDOW_SEC: int = 300

# Long window: behavioral trend analysis (default 60 minutes)
LONG_WINDOW_SEC: int = 3600

# Computed buffer sizes based on collection interval
SHORT_BUFFER_SIZE: int = int(SHORT_WINDOW_SEC / COLLECTION_INTERVAL_SEC)   # 150
LONG_BUFFER_SIZE: int = int(LONG_WINDOW_SEC / COLLECTION_INTERVAL_SEC)     # 1800

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

# Stress score threshold to trigger an alert
ALERT_STRESS_THRESHOLD: float = 70.0

# Number of consecutive high-stress readings before alert fires
ALERT_CONSECUTIVE_COUNT: int = 5  # 5 readings × 2s = 10 seconds

# Cooldown period after an alert fires (seconds)
ALERT_COOLDOWN_SEC: float = 60.0

# ---------------------------------------------------------------------------
# API Server
# ---------------------------------------------------------------------------

# API server host and port
API_HOST: str = "127.0.0.1"
API_PORT: int = 8740

# WebSocket broadcast interval (seconds) — matches collection interval
WS_BROADCAST_INTERVAL: float = COLLECTION_INTERVAL_SEC
