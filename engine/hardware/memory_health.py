"""Memory health probe — utilization, swap pressure, module info."""

from __future__ import annotations

import logging
import sys
import time

import psutil

from engine.hardware._shell import parse_json, run_powershell

logger = logging.getLogger(__name__)

STATUS_HEALTHY = "healthy"
STATUS_WARNING = "warning"
STATUS_CRITICAL = "critical"
STATUS_UNKNOWN = "unknown"

USE_WARN_PCT = 85.0
USE_CRIT_PCT = 95.0
SWAP_WARN_PCT = 25.0
SWAP_CRIT_PCT = 60.0

# Persistent swap I/O snapshot — used to compute deltas between probes.
_last_swap_sample: tuple[float, int, int] | None = None  # (ts, sin, sout)


def _swap_rate_bytes_per_sec() -> tuple[float | None, float | None]:
    """Return (swap-in B/s, swap-out B/s) since the previous probe."""
    global _last_swap_sample
    try:
        sw = psutil.swap_memory()
    except Exception:
        return None, None
    now = time.time()
    sin = int(getattr(sw, "sin", 0) or 0)
    sout = int(getattr(sw, "sout", 0) or 0)

    prev = _last_swap_sample
    _last_swap_sample = (now, sin, sout)
    if prev is None:
        return None, None
    pts, psin, psout = prev
    dt = now - pts
    if dt <= 0:
        return None, None
    return max(0.0, (sin - psin) / dt), max(0.0, (sout - psout) / dt)


def _windows_modules() -> list[dict]:
    """Return DIMM module info on Windows (best-effort)."""
    if sys.platform != "win32":
        return []
    res = run_powershell(
        "Get-CimInstance -ClassName Win32_PhysicalMemory | "
        "Select-Object Manufacturer, PartNumber, Capacity, Speed, ConfiguredClockSpeed, "
        "DeviceLocator, FormFactor | ConvertTo-Json -Compress",
        timeout=15.0,
    )
    if not res.ok or not res.stdout.strip():
        return []
    data = parse_json(res.stdout)
    if data is None:
        return []
    rows = data if isinstance(data, list) else [data]
    out: list[dict] = []
    for r in rows:
        if not isinstance(r, dict):
            continue
        out.append(
            {
                "manufacturer": (r.get("Manufacturer") or "").strip() or None,
                "part_number": (r.get("PartNumber") or "").strip() or None,
                "capacity_bytes": int(r.get("Capacity") or 0) or None,
                "speed_mhz": r.get("Speed"),
                "configured_speed_mhz": r.get("ConfiguredClockSpeed"),
                "slot": r.get("DeviceLocator"),
                "form_factor": _form_factor_label(r.get("FormFactor")),
            }
        )
    return out


def _form_factor_label(code: int | None) -> str | None:
    # https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-physicalmemory
    table = {
        0: "Unknown",
        8: "DIMM",
        9: "SODIMM",
        12: "FB-DIMM",
        13: "DIMM",
        15: "DIMM",
        20: "DIMM",
    }
    try:
        return table.get(int(code) if code is not None else 0)
    except (TypeError, ValueError):
        return None


def probe_memory() -> dict:
    """Return memory health snapshot."""
    issues: list[str] = []
    metrics: dict = {}
    items: list[dict] = _windows_modules()

    vm = psutil.virtual_memory()
    metrics.update(
        {
            "total_bytes": int(vm.total),
            "used_bytes": int(vm.used),
            "available_bytes": int(vm.available),
            "percent": round(float(vm.percent), 1),
        }
    )

    try:
        sw = psutil.swap_memory()
        metrics["swap_total_bytes"] = int(sw.total)
        metrics["swap_used_bytes"] = int(sw.used)
        metrics["swap_percent"] = round(float(sw.percent), 1)
    except Exception:  # noqa: BLE001
        metrics["swap_total_bytes"] = None

    sin_rate, sout_rate = _swap_rate_bytes_per_sec()
    metrics["swap_in_bps"] = round(sin_rate, 1) if sin_rate is not None else None
    metrics["swap_out_bps"] = round(sout_rate, 1) if sout_rate is not None else None

    status = STATUS_HEALTHY
    if vm.percent >= USE_CRIT_PCT:
        status = STATUS_CRITICAL
        issues.append(f"Memory utilisation at {vm.percent:.0f}%")
    elif vm.percent >= USE_WARN_PCT:
        status = STATUS_WARNING
        issues.append(f"Memory utilisation at {vm.percent:.0f}%")

    swap_percent = float(metrics.get("swap_percent") or 0.0)
    if swap_percent >= SWAP_CRIT_PCT:
        status = STATUS_CRITICAL
        issues.append(f"Swap utilisation at {swap_percent:.0f}%")
    elif swap_percent >= SWAP_WARN_PCT and status == STATUS_HEALTHY:
        status = STATUS_WARNING
        issues.append(f"Swap utilisation at {swap_percent:.0f}%")

    # Heuristic — if swap-out is hot the system is paging actively.
    if (
        sout_rate is not None
        and sout_rate > 5 * 1024 * 1024
        and status == STATUS_HEALTHY
    ):
        status = STATUS_WARNING
        issues.append("Active paging to disk")

    return {
        "status": status,
        "metrics": metrics,
        "issues": issues,
        "items": items,
    }


__all__ = ["probe_memory"]
