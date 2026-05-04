"""Tests for persisted user preferences."""

from engine.user_preferences import UserPreferences, canonical_process_name


def test_canonical_process_name():
    assert canonical_process_name("Chrome") == "chrome.exe"
    assert canonical_process_name("foo.exe") == "foo.exe"


def test_from_dict_coerces_lists_and_bounds():
    p = UserPreferences.from_dict(
        {
            "alert_cpu_percent": 200,
            "alert_memory_percent": 0,
            "safeguard_process_names": "a.exe, b",
            "safeguard_enabled": True,
        }
    )
    assert p.alert_cpu_percent == 100.0
    assert p.alert_memory_percent == 1.0
    assert p.safeguard_enabled is True
    assert "a.exe" in p.safeguard_process_names
    assert "b.exe" in p.safeguard_process_names
