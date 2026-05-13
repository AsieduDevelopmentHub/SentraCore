"""Disk health probe — SMART status, free space, media type.

Each platform has a different "best" source for SMART data:

* **Windows** — ``Get-PhysicalDisk`` (PowerShell, ships with Windows 8+) exposes
  ``HealthStatus``, ``OperationalStatus``, ``MediaType``, and ``Size`` without
  requiring a third-party tool.
* **Linux / macOS** — invoke ``smartctl --json`` when it is on ``PATH``;
  otherwise the probe falls back to free-space-only reporting.

If neither source is available we still publish per-volume free-space data
from :mod:`psutil`, because that's the metric the user notices first.
"""

from __future__ import annotations

import logging
import sys

import psutil

from engine.hardware._shell import parse_json, run, run_powershell, which

logger = logging.getLogger(__name__)

STATUS_HEALTHY = "healthy"
STATUS_WARNING = "warning"
STATUS_CRITICAL = "critical"
STATUS_UNKNOWN = "unknown"

FREE_WARN_PCT = 15.0
FREE_CRIT_PCT = 5.0


def _windows_physical_disks() -> list[dict]:
    """Return a list of physical disks via Get-PhysicalDisk."""
    res = run_powershell(
        "Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, Model, "
        "SerialNumber, MediaType, BusType, Size, HealthStatus, "
        "OperationalStatus, Usage | ConvertTo-Json -Compress",
        # PowerShell cold-start can take 6-10s on a fresh process; give it
        # headroom rather than mis-reporting a healthy disk as "unknown".
        timeout=20.0,
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
        health = (r.get("HealthStatus") or "").strip()
        op = r.get("OperationalStatus")
        if isinstance(op, list):
            op_str = ", ".join(str(o) for o in op if o)
        else:
            op_str = str(op or "").strip()
        status = STATUS_HEALTHY
        issues: list[str] = []
        if health.lower() == "warning":
            status = STATUS_WARNING
            issues.append("HealthStatus reports Warning")
        elif health.lower() == "unhealthy":
            status = STATUS_CRITICAL
            issues.append("HealthStatus reports Unhealthy")
        elif not health or health.lower() in ("unknown", ""):
            status = STATUS_UNKNOWN

        if op_str and op_str.lower() not in ("ok", ""):
            if status == STATUS_HEALTHY:
                status = STATUS_WARNING
            issues.append(f"Operational status: {op_str}")

        out.append(
            {
                "device_id": str(r.get("DeviceId") or ""),
                "name": r.get("FriendlyName") or r.get("Model") or "Disk",
                "model": r.get("Model"),
                "serial": (r.get("SerialNumber") or None),
                "media_type": _normalize_media(r.get("MediaType")),
                "bus_type": r.get("BusType"),
                "size_bytes": int(r.get("Size") or 0) or None,
                "smart": {
                    "source": "Get-PhysicalDisk",
                    "health_status": health or None,
                    "operational_status": op_str or None,
                },
                "status": status,
                "issues": issues,
            }
        )
    return out


def _normalize_media(value) -> str | None:
    if value is None:
        return None
    s = str(value).strip().lower()
    return {
        "ssd": "SSD",
        "hdd": "HDD",
        "scm": "SCM",
        "unspecified": None,
        "0": None,
        "3": "HDD",
        "4": "SSD",
        "5": "SCM",
    }.get(s, str(value))


def _smartctl_devices() -> list[dict]:
    """Use smartctl --json to enumerate + grade disks on Linux/macOS."""
    if not which("smartctl"):
        return []
    scan = run(["smartctl", "--scan-open", "--json"], timeout=5.0)
    if not scan.ok:
        return []
    parsed = parse_json(scan.stdout) or {}
    devices = parsed.get("devices") or []
    out: list[dict] = []
    for dev in devices:
        if not isinstance(dev, dict):
            continue
        path = dev.get("name") or dev.get("info_name")
        if not path:
            continue
        info = run(["smartctl", "-a", "--json", path], timeout=6.0)
        info_json = parse_json(info.stdout) or {}
        model = info_json.get("model_name") or info_json.get("device", {}).get(
            "info_name"
        )
        serial = info_json.get("serial_number")
        size = info_json.get("user_capacity", {}).get("bytes")
        smart = info_json.get("smart_status", {})
        passed = smart.get("passed")
        status = (
            STATUS_HEALTHY
            if passed
            else (STATUS_CRITICAL if passed is False else STATUS_UNKNOWN)
        )
        issues: list[str] = []
        if passed is False:
            issues.append("SMART overall: FAILED")
        elif passed is None:
            issues.append("SMART status not reported")
        out.append(
            {
                "device_id": str(path),
                "name": model or path,
                "model": model,
                "serial": serial,
                "media_type": None,
                "bus_type": None,
                "size_bytes": int(size) if size else None,
                "smart": {
                    "source": "smartctl",
                    "passed": passed,
                    "attributes_present": bool(info_json.get("ata_smart_attributes")),
                },
                "status": status,
                "issues": issues,
            }
        )
    return out


def _volumes() -> list[dict]:
    """List logical volumes with usage stats."""
    vols: list[dict] = []
    try:
        partitions = psutil.disk_partitions(all=False)
    except Exception:  # noqa: BLE001
        partitions = []
    for p in partitions:
        try:
            usage = psutil.disk_usage(p.mountpoint)
        except (PermissionError, OSError):
            continue
        free_pct = 100.0 - float(usage.percent)
        vol_status = STATUS_HEALTHY
        issues: list[str] = []
        if free_pct <= FREE_CRIT_PCT:
            vol_status = STATUS_CRITICAL
            issues.append(f"Only {free_pct:.0f}% free")
        elif free_pct <= FREE_WARN_PCT:
            vol_status = STATUS_WARNING
            issues.append(f"{free_pct:.0f}% free")
        vols.append(
            {
                "mountpoint": p.mountpoint,
                "device": p.device,
                "fstype": p.fstype,
                "total_bytes": int(usage.total),
                "used_bytes": int(usage.used),
                "free_bytes": int(usage.free),
                "free_percent": round(free_pct, 1),
                "status": vol_status,
                "issues": issues,
            }
        )
    return vols


def probe_disks() -> dict:
    """Return disk health snapshot."""
    if sys.platform == "win32":
        physical = _windows_physical_disks()
    else:
        physical = _smartctl_devices()
    volumes = _volumes()

    # Aggregate status — worst of physical-disk status + volume free-space status.
    all_statuses: list[str] = [d.get("status", STATUS_UNKNOWN) for d in physical]
    all_statuses += [v.get("status", STATUS_UNKNOWN) for v in volumes]
    status = _worst(all_statuses) if all_statuses else STATUS_UNKNOWN

    issues: list[str] = []
    for d in physical:
        for i in d.get("issues") or []:
            issues.append(f"{d.get('name', 'Disk')}: {i}")
    for v in volumes:
        for i in v.get("issues") or []:
            issues.append(f"{v.get('mountpoint', '?')}: {i}")

    return {
        "status": status,
        "metrics": {
            "physical_count": len(physical),
            "volume_count": len(volumes),
        },
        "issues": issues,
        "items": [{"kind": "physical", **d} for d in physical]
        + [{"kind": "volume", **v} for v in volumes],
    }


_RANK = {STATUS_HEALTHY: 0, STATUS_UNKNOWN: 1, STATUS_WARNING: 2, STATUS_CRITICAL: 3}


def _worst(statuses: list[str]) -> str:
    return max(statuses, key=lambda s: _RANK.get(s, 1))


__all__ = ["probe_disks"]
