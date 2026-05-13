# Hardware Health

The **Hardware** tab in the desktop dashboard is SentraCore's
CrystalDiskInfo-style answer to "how is my machine doing physically?" It
grades CPU, RAM, and storage devices independently, surfaces vendor metadata
when the OS exposes it, and aggregates everything into a single overall
status the user can glance at.

Implementation lives in `engine/hardware/`:

```text
engine/hardware/
├── __init__.py          # aggregation + 30s TTL cache
├── _shell.py            # safe subprocess + PowerShell helper
├── cpu_health.py        # load / freq / throttle / temps
├── memory_health.py     # utilisation, swap pressure, module info
└── disk_health.py       # SMART + free space per volume
```

Every probe is *defensive* — hardware introspection is wildly inconsistent
across OSes and driver setups, so a probe that cannot obtain a metric
reports `unknown` with a hint rather than raising. Nothing here should ever
take the engine down.

---

## Status taxonomy

Each component reports one of:

| Status     | Meaning |
|---|---|
| `healthy`  | All metrics within healthy bounds. |
| `warning`  | Elevated but not dangerous (e.g. CPU at 86%, disk at 14% free). |
| `critical` | Action recommended (CPU > 92°C, disk < 5% free, SMART failed). |
| `unknown`  | A probe could not obtain enough information (very common for CPU temps on Windows without vendor drivers). |

The overall status is the *worst* component status, with ordering:
`critical > warning > unknown > healthy`.

---

## CPU probe (`cpu_health.py`)

* **Load** — `psutil.cpu_percent(interval=0.4, percpu=True)`; reports average,
  peak core, and per-core standard deviation.
* **Frequency** — `psutil.cpu_freq()`. Computes `current/max` ratio; flags
  *suspected throttling* only when the ratio is below 65% **and** load is at
  least 50% (idle cores legitimately drop their clock).
* **Temperature** —
  * Linux/macOS: `psutil.sensors_temperatures()`, scanning chip labels for
    `coretemp / k10temp / cpu / zenpower`.
  * Windows: best-effort `Get-CimInstance MSAcpi_ThermalZoneTemperature`.
    Many consumer machines do not populate it — that is *expected* and the UI
    shows "sensor unavailable" rather than an alarm.
* **Thresholds**: warning ≥ 80°C, critical ≥ 92°C; load warning ≥ 85%,
  critical ≥ 95%.

---

## Memory probe (`memory_health.py`)

* `psutil.virtual_memory()` for utilisation, `psutil.swap_memory()` for swap.
* **Active paging detection** — caches the previous `(sin, sout)` counters
  and computes a swap-out byte-rate between calls. Above 5 MiB/s while
  everything else looks healthy ⇒ warning, because the machine is paging
  *right now*.
* **Module inventory (Windows)** — `Get-CimInstance Win32_PhysicalMemory`
  yields slot, manufacturer, part number, capacity, JEDEC speed, and the
  configured clock speed. We surface the configured speed when it differs
  from the rated speed (a common XMP-not-enabled trap).
* **Thresholds**: usage warning ≥ 85%, critical ≥ 95%; swap warning ≥ 25%,
  critical ≥ 60%.

---

## Disk probe (`disk_health.py`)

Two layers reported separately:

1. **Physical disks** — vendor-grade SMART status.
   * Windows: `Get-PhysicalDisk` returns `HealthStatus`,
     `OperationalStatus`, `MediaType`, `BusType`, capacity, serial, model.
     `Healthy` ⇒ healthy, `Warning` ⇒ warning, `Unhealthy` ⇒ critical.
   * Linux/macOS: `smartctl --scan-open --json` lists devices, then
     `smartctl -a --json <dev>` per device for `smart_status.passed`. If
     `smartctl` is not on PATH the probe is silently skipped — installing
     `smartmontools` upgrades the view.
2. **Logical volumes** — `psutil.disk_partitions()` + `psutil.disk_usage()`.
   Warning at ≤ 15% free, critical at ≤ 5% free.

The aggregate component status is the worst of both layers, so a healthy
SSD with a 4%-full volume on it still reads critical.

### Why `Get-PhysicalDisk` and not `wmic`?

`wmic` is deprecated in Windows 11 and removed in some future builds.
`Get-PhysicalDisk` ships with the in-box Storage module on Windows 8+ and
emits structured JSON via `ConvertTo-Json`, which keeps our parser
simple.

### Subprocess timeouts

PowerShell cold-start can take 6–10 s. The probes deliberately use long
timeouts (10–20 s) — a missed reading because PowerShell wasn't ready yet
would cause a healthy disk to silently degrade to `unknown`, which is the
worst possible UX.

---

## Aggregation + caching (`engine/hardware/__init__.py`)

`collect_health(ttl_sec=30, refresh=False)`:

* Runs the three probes inside a guard that converts exceptions into
  `unknown` (`_safe`).
* Caches the resulting payload for `ttl_sec` seconds. The dashboard polls
  every 30 s, and the engine itself can be hit from the API without
  re-launching subprocesses on every call. Pass `refresh=True` to bypass.

Payload shape:

```json
{
  "ts": 1736187264.55,
  "overall": "healthy",
  "components": {
    "cpu":    {"status": "healthy", "metrics": {...}, "issues": [], "items": []},
    "memory": {"status": "healthy", "metrics": {...}, "issues": [], "items": [...]},
    "disks":  {"status": "healthy", "metrics": {...}, "issues": [], "items": [...]}
  }
}
```

---

## REST API

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/v1/hardware/health?refresh=false` | Aggregated CPU / memory / disk health snapshot |

The endpoint runs the probes via `asyncio.to_thread`, so the FastAPI event
loop stays responsive while PowerShell warms up.

---

## Dashboard

* New navigation rail entry **Hardware** (between *Diagnostics* and
  *Storage*) using the `monitor_heart` icon.
* `HardwareScreen` renders three component cards (CPU, Memory, Disks),
  each with a status pill, key metrics, and the list of issues that
  drove the status.
* Memory card lists every detected DIMM with slot / part number / configured
  clock speed.
* Disk card splits physical disks (SMART status, media type, bus type,
  capacity, serial) from logical volumes (free-space progress bar).
* `Refresh` button triggers `?refresh=true`; otherwise the screen polls
  every 30 seconds.

---

## Tests

`tests/test_hardware_health.py` covers:

* `worst_status()` ordering across `healthy / unknown / warning / critical`.
* `collect_health()` TTL cache hit & `refresh=True` bypass.
* Probe failure isolation (one boom doesn't flip the overall to crash).
* `disk_health.probe_disks()` aggregating volume free-space + physical
  status, plus the all-empty `unknown` path.
* `memory_health.probe_memory()` thresholds (warning on high RAM, critical
  on swap saturation).
