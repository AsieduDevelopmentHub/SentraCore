"""CPU health probe — temperature, load, frequency throttling, per-core balance."""

from __future__ import annotations

import logging
import statistics
import sys

import psutil

from engine.hardware._shell import parse_json, run_powershell

logger = logging.getLogger(__name__)

STATUS_HEALTHY = "healthy"
STATUS_WARNING = "warning"
STATUS_CRITICAL = "critical"
STATUS_UNKNOWN = "unknown"

# Thresholds — conservative; tweak via observation, not by hunch.
TEMP_WARN_C = 80.0
TEMP_CRIT_C = 92.0
LOAD_WARN_PCT = 85.0
LOAD_CRIT_PCT = 95.0
THROTTLE_RATIO = 0.65  # current_freq / max_freq below this = throttle suspicion


def _read_temperatures() -> tuple[float | None, list[dict]]:
    """Return (max_temp_c, per-sensor list). psutil + Linux/macOS only."""
    if not hasattr(psutil, "sensors_temperatures"):
        return None, []
    try:
        all_sensors = psutil.sensors_temperatures(fahrenheit=False)
    except Exception as exc:  # noqa: BLE001 — sensors API differs across distros
        logger.debug("sensors_temperatures failed: %s", exc)
        return None, []

    sensors: list[dict] = []
    cpu_temps: list[float] = []
    for chip, readings in all_sensors.items():
        chip_lower = (chip or "").lower()
        is_cpu = any(
            key in chip_lower for key in ("coretemp", "k10temp", "cpu", "zenpower")
        )
        for r in readings:
            sensors.append(
                {
                    "chip": chip,
                    "label": r.label,
                    "current_c": r.current,
                    "high_c": r.high,
                    "critical_c": r.critical,
                }
            )
            if is_cpu and r.current is not None:
                cpu_temps.append(float(r.current))

    if not cpu_temps:
        return None, sensors
    return max(cpu_temps), sensors


def _read_temperature_windows() -> float | None:
    """Best-effort temperature read on Windows.

    The widely-available API is the legacy WMI ``MSAcpi_ThermalZoneTemperature``
    class, which reports in tenths of Kelvin and is *not* always populated by
    consumer hardware drivers. We try it once and accept ``None`` quickly.
    """
    if sys.platform != "win32":
        return None
    res = run_powershell(
        "Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature "
        "-ErrorAction SilentlyContinue | Select-Object -ExpandProperty CurrentTemperature "
        "| ConvertTo-Json -Compress",
        timeout=10.0,
    )
    if not res.ok or not res.stdout.strip():
        return None
    data = parse_json(res.stdout)
    if data is None:
        return None
    values = data if isinstance(data, list) else [data]
    temps: list[float] = []
    for v in values:
        try:
            tenths_k = float(v)
        except (TypeError, ValueError):
            continue
        # WMI reports in tenths of Kelvin: (val / 10) - 273.15 = °C.
        c = (tenths_k / 10.0) - 273.15
        if -20.0 < c < 130.0:
            temps.append(c)
    return max(temps) if temps else None


def _read_freq() -> tuple[float | None, float | None]:
    try:
        freq = psutil.cpu_freq()
    except Exception:  # noqa: BLE001 — cpu_freq is flaky on some VMs
        return None, None
    if freq is None:
        return None, None
    return (
        float(freq.current) if freq.current is not None else None,
        float(freq.max) if freq.max is not None else None,
    )


def probe_cpu() -> dict:
    """Return CPU health snapshot."""
    issues: list[str] = []
    metrics: dict = {}

    # ----- load -----
    per_core = psutil.cpu_percent(interval=0.4, percpu=True) or []
    avg_load = sum(per_core) / len(per_core) if per_core else 0.0
    max_core = max(per_core) if per_core else 0.0
    metrics["load_avg_pct"] = round(avg_load, 1)
    metrics["load_max_core_pct"] = round(max_core, 1)
    metrics["cores_logical"] = psutil.cpu_count(logical=True) or 0
    metrics["cores_physical"] = psutil.cpu_count(logical=False) or 0
    if len(per_core) >= 2:
        metrics["load_core_stdev"] = round(statistics.pstdev(per_core), 2)

    # ----- frequency / throttle -----
    cur_freq, max_freq = _read_freq()
    metrics["freq_current_mhz"] = round(cur_freq, 1) if cur_freq is not None else None
    metrics["freq_max_mhz"] = round(max_freq, 1) if max_freq is not None else None
    throttling = False
    if cur_freq and max_freq and max_freq > 0:
        ratio = cur_freq / max_freq
        metrics["freq_ratio"] = round(ratio, 3)
        # Only flag throttle when the CPU is under load — idle cores legitimately
        # drop their clock.
        if ratio < THROTTLE_RATIO and avg_load >= 50.0:
            throttling = True
            issues.append(
                f"CPU clock at {ratio:.0%} of max while under {avg_load:.0f}% load"
            )

    # ----- temperatures -----
    max_temp: float | None
    sensors: list[dict]
    if sys.platform == "win32":
        max_temp = _read_temperature_windows()
        sensors = []
    else:
        max_temp, sensors = _read_temperatures()
    metrics["max_temp_c"] = round(max_temp, 1) if max_temp is not None else None
    metrics["sensors"] = sensors

    # ----- grade -----
    status = STATUS_HEALTHY
    if max_temp is None and sys.platform == "win32":
        # On Windows temps are usually only accessible via vendor drivers; UI
        # tells the user this is normal, not an alarm.
        pass

    if max_temp is not None:
        if max_temp >= TEMP_CRIT_C:
            status = STATUS_CRITICAL
            issues.append(f"CPU temperature {max_temp:.0f}°C is critical")
        elif max_temp >= TEMP_WARN_C and status != STATUS_CRITICAL:
            status = STATUS_WARNING
            issues.append(f"CPU temperature {max_temp:.0f}°C is elevated")

    if avg_load >= LOAD_CRIT_PCT:
        status = STATUS_CRITICAL
        issues.append(f"CPU load sustained at {avg_load:.0f}%")
    elif avg_load >= LOAD_WARN_PCT and status == STATUS_HEALTHY:
        status = STATUS_WARNING
        issues.append(f"CPU load elevated at {avg_load:.0f}%")

    if throttling and status == STATUS_HEALTHY:
        status = STATUS_WARNING

    return {
        "status": status,
        "metrics": metrics,
        "issues": issues,
        "items": [],
    }


__all__ = ["probe_cpu"]
