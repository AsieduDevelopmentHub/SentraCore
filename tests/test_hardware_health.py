"""Unit tests for engine.hardware health probes + aggregation."""

from __future__ import annotations

from unittest.mock import patch

import pytest

from engine.hardware import (
    STATUS_CRITICAL,
    STATUS_HEALTHY,
    STATUS_UNKNOWN,
    STATUS_WARNING,
    collect_component,
    collect_health,
    reset_cache_for_tests,
    worst_status,
)
from engine.hardware import disk_health, memory_health


# --------------------------------------------------------------------------- #
# Aggregation
# --------------------------------------------------------------------------- #


def test_worst_status_picks_most_severe() -> None:
    assert (
        worst_status([STATUS_HEALTHY, STATUS_WARNING, STATUS_HEALTHY]) == STATUS_WARNING
    )
    assert (
        worst_status([STATUS_HEALTHY, STATUS_CRITICAL, STATUS_WARNING])
        == STATUS_CRITICAL
    )
    assert worst_status([STATUS_HEALTHY, STATUS_HEALTHY]) == STATUS_HEALTHY
    assert worst_status([]) == STATUS_UNKNOWN
    # Unknown ranks above healthy but below warning.
    assert worst_status([STATUS_HEALTHY, STATUS_UNKNOWN]) == STATUS_UNKNOWN
    assert worst_status([STATUS_UNKNOWN, STATUS_WARNING]) == STATUS_WARNING


def test_collect_health_caches_results() -> None:
    reset_cache_for_tests()
    payload = {"status": STATUS_HEALTHY, "metrics": {}, "issues": [], "items": []}

    call_counts = {"cpu": 0, "memory": 0, "disks": 0}

    def make_probe(name):
        def _probe():
            call_counts[name] += 1
            return payload

        return _probe

    with (
        patch("engine.hardware.probe_cpu", side_effect=make_probe("cpu")),
        patch("engine.hardware.probe_memory", side_effect=make_probe("memory")),
        patch("engine.hardware.probe_disks", side_effect=make_probe("disks")),
    ):
        a = collect_health(ttl_sec=60)
        b = collect_health(ttl_sec=60)
    assert a is b
    assert call_counts == {"cpu": 1, "memory": 1, "disks": 1}


def test_collect_health_refresh_bypasses_cache() -> None:
    reset_cache_for_tests()
    payload = {"status": STATUS_HEALTHY, "metrics": {}, "issues": [], "items": []}

    counts = {"n": 0}

    def probe():
        counts["n"] += 1
        return payload

    with (
        patch("engine.hardware.probe_cpu", side_effect=probe),
        patch("engine.hardware.probe_memory", side_effect=probe),
        patch("engine.hardware.probe_disks", side_effect=probe),
    ):
        collect_health(ttl_sec=60)
        collect_health(ttl_sec=60, refresh=True)
    assert counts["n"] == 6  # 3 probes × 2 calls


def test_failed_probe_does_not_crash() -> None:
    reset_cache_for_tests()
    payload = {"status": STATUS_HEALTHY, "metrics": {}, "issues": [], "items": []}

    def boom():
        raise RuntimeError("nope")

    with (
        patch("engine.hardware.probe_cpu", side_effect=boom),
        patch("engine.hardware.probe_memory", return_value=payload),
        patch("engine.hardware.probe_disks", return_value=payload),
    ):
        result = collect_health(refresh=True)
    assert result["components"]["cpu"]["status"] == STATUS_UNKNOWN
    # Worst status is unknown when one probe failed but the others are healthy.
    assert result["overall"] in (STATUS_UNKNOWN, STATUS_HEALTHY)


def test_collect_component_invalid_target() -> None:
    reset_cache_for_tests()
    with pytest.raises(ValueError, match="invalid hardware test target"):
        collect_component("gpu")
    with pytest.raises(ValueError, match="invalid hardware test target"):
        collect_component("")


def test_collect_component_disk_alias_runs_disks_probe() -> None:
    reset_cache_for_tests()
    payload = {"status": STATUS_HEALTHY, "metrics": {}, "issues": [], "items": []}
    counts = {"n": 0}

    def probe_disks():
        counts["n"] += 1
        return payload

    with patch("engine.hardware.probe_disks", side_effect=probe_disks):
        out = collect_component("disk")
    assert counts["n"] == 1
    assert out["components"]["disks"] == payload


def test_collect_component_merges_other_fields_from_cache() -> None:
    reset_cache_for_tests()
    cpu = {"status": STATUS_HEALTHY, "metrics": {"k": 1}, "issues": [], "items": []}
    mem = {"status": STATUS_WARNING, "metrics": {}, "issues": ["high"], "items": []}
    disk = {"status": STATUS_HEALTHY, "metrics": {}, "issues": [], "items": []}
    with (
        patch("engine.hardware.probe_cpu", return_value=cpu),
        patch("engine.hardware.probe_memory", return_value=mem),
        patch("engine.hardware.probe_disks", return_value=disk),
    ):
        collect_health(refresh=True, ttl_sec=120)

    new_cpu = {"status": STATUS_CRITICAL, "metrics": {}, "issues": [], "items": []}
    counts = {"cpu": 0, "memory": 0, "disks": 0}

    def track_cpu():
        counts["cpu"] += 1
        return new_cpu

    def track_memory():
        counts["memory"] += 1
        return mem

    def track_disks():
        counts["disks"] += 1
        return disk

    with (
        patch("engine.hardware.probe_cpu", side_effect=track_cpu),
        patch("engine.hardware.probe_memory", side_effect=track_memory),
        patch("engine.hardware.probe_disks", side_effect=track_disks),
    ):
        out = collect_component("cpu", ttl_sec=120)
    assert counts == {"cpu": 1, "memory": 0, "disks": 0}
    assert out["components"]["cpu"] == new_cpu
    assert out["components"]["memory"] == mem
    assert out["components"]["disks"] == disk
    assert out["overall"] == STATUS_CRITICAL


def test_collect_component_without_cache_seeds_unknown_peers() -> None:
    reset_cache_for_tests()
    payload = {"status": STATUS_HEALTHY, "metrics": {}, "issues": [], "items": []}
    with patch("engine.hardware.probe_cpu", return_value=payload):
        out = collect_component("cpu")
    assert out["components"]["cpu"] == payload
    assert out["components"]["memory"]["status"] == STATUS_UNKNOWN
    assert out["components"]["disks"]["status"] == STATUS_UNKNOWN


# --------------------------------------------------------------------------- #
# disk_health.probe_disks() — verify it composes physical + volume status
# --------------------------------------------------------------------------- #


def test_probe_disks_aggregates_volumes(monkeypatch: pytest.MonkeyPatch) -> None:
    # Fake one physical disk (healthy) and two volumes — one critical-on-free.
    monkeypatch.setattr(
        disk_health,
        "_windows_physical_disks",
        lambda: [
            {
                "device_id": "0",
                "name": "Test SSD",
                "media_type": "SSD",
                "bus_type": "SATA",
                "size_bytes": 256_000_000_000,
                "smart": {"source": "Get-PhysicalDisk", "health_status": "Healthy"},
                "status": STATUS_HEALTHY,
                "issues": [],
            }
        ],
    )
    monkeypatch.setattr(disk_health, "_smartctl_devices", lambda: [])
    monkeypatch.setattr(
        disk_health,
        "_volumes",
        lambda: [
            {
                "mountpoint": "C:\\",
                "device": "C:\\",
                "fstype": "NTFS",
                "total_bytes": 100,
                "used_bytes": 99,
                "free_bytes": 1,
                "free_percent": 1.0,
                "status": STATUS_CRITICAL,
                "issues": ["Only 1% free"],
            }
        ],
    )

    result = disk_health.probe_disks()
    assert result["status"] == STATUS_CRITICAL
    assert any("C:" in i for i in result["issues"])
    assert result["metrics"]["physical_count"] == 1
    assert result["metrics"]["volume_count"] == 1


def test_probe_disks_unknown_when_nothing_detected(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(disk_health, "_windows_physical_disks", lambda: [])
    monkeypatch.setattr(disk_health, "_smartctl_devices", lambda: [])
    monkeypatch.setattr(disk_health, "_volumes", lambda: [])

    result = disk_health.probe_disks()
    assert result["status"] == STATUS_UNKNOWN


# --------------------------------------------------------------------------- #
# memory_health.probe_memory() — threshold behaviour
# --------------------------------------------------------------------------- #


class _FakeVM:
    def __init__(self, percent: float, total: int = 16 * 1024**3) -> None:
        self.percent = percent
        self.total = total
        self.used = int(total * percent / 100.0)
        self.available = total - self.used


class _FakeSwap:
    def __init__(self, percent: float, total: int = 4 * 1024**3) -> None:
        self.percent = percent
        self.total = total
        self.used = int(total * percent / 100.0)
        self.sin = 0
        self.sout = 0


def test_probe_memory_warns_on_high_usage(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        memory_health.psutil, "virtual_memory", lambda: _FakeVM(percent=90.0)
    )
    monkeypatch.setattr(
        memory_health.psutil, "swap_memory", lambda: _FakeSwap(percent=5.0)
    )
    monkeypatch.setattr(memory_health, "_windows_modules", lambda: [])
    monkeypatch.setattr(memory_health, "_last_swap_sample", None)

    result = memory_health.probe_memory()
    assert result["status"] == STATUS_WARNING
    assert any("Memory utilisation" in i for i in result["issues"])


def test_probe_memory_critical_on_swap_saturation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        memory_health.psutil, "virtual_memory", lambda: _FakeVM(percent=50.0)
    )
    monkeypatch.setattr(
        memory_health.psutil, "swap_memory", lambda: _FakeSwap(percent=80.0)
    )
    monkeypatch.setattr(memory_health, "_windows_modules", lambda: [])
    monkeypatch.setattr(memory_health, "_last_swap_sample", None)

    result = memory_health.probe_memory()
    assert result["status"] == STATUS_CRITICAL
