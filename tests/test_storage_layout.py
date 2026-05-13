"""Tests for engine.storage.{paths,atomic,migrate}."""

from __future__ import annotations

import importlib
import json
import os
import sys
from pathlib import Path

import pytest


@pytest.fixture()
def isolated_datastore(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Repoint engine.config to a temporary datastore root and reload modules."""
    monkeypatch.setenv("SENTRACORE_DATA_DIR", str(tmp_path))
    for mod in [
        "engine.storage.migrate",
        "engine.storage.paths",
        "engine.storage.atomic",
        "engine.storage",
        "engine.config",
        "engine.user_preferences",
        "engine.history.history_store",
        "engine.history",
        "engine.state.runtime_state",
        "engine.state",
    ]:
        sys.modules.pop(mod, None)
    importlib.import_module("engine.config")
    importlib.import_module("engine.storage")
    return tmp_path


def test_ensure_layout_creates_all_subdirs(isolated_datastore: Path) -> None:
    from engine.storage import paths as p

    p.ensure_layout()
    for sub in ("config", "state", "history", "logs", "cache", "reports"):
        assert (isolated_datastore / sub).is_dir(), sub


def test_atomic_write_replaces_file_in_one_step(isolated_datastore: Path) -> None:
    from engine.storage.atomic import read_json, write_json_atomic

    target = isolated_datastore / "config" / "demo.json"
    write_json_atomic(target, {"a": 1})
    assert read_json(target) == {"a": 1}

    # Overwriting must not leave temp files behind.
    write_json_atomic(target, {"a": 2})
    siblings = [c.name for c in target.parent.iterdir()]
    assert siblings == ["demo.json"], siblings
    assert read_json(target) == {"a": 2}


def test_read_json_tolerates_missing_and_malformed(isolated_datastore: Path) -> None:
    from engine.storage.atomic import read_json

    missing = isolated_datastore / "nope.json"
    assert read_json(missing) is None
    assert read_json(missing, default={"x": 1}) == {"x": 1}

    bad = isolated_datastore / "bad.json"
    bad.write_text("{not json", encoding="utf-8")
    assert read_json(bad, default=[]) == []


def test_migration_moves_flat_files_once(isolated_datastore: Path) -> None:
    # Seed the legacy flat layout.
    (isolated_datastore / "baseline.json").write_text(
        json.dumps({"global": {"cpu_percent": {"count": 0}}}), encoding="utf-8"
    )
    (isolated_datastore / "user_preferences.json").write_text(
        json.dumps({"alert_cpu_percent": 50}), encoding="utf-8"
    )

    from engine.storage.migrate import run_migrations

    result = run_migrations()
    assert result["applied"] is True
    assert any("baseline.json" in m for m in result["moved"])
    assert (isolated_datastore / "state" / "baseline.json").is_file()
    assert (isolated_datastore / "config" / "user_preferences.json").is_file()
    assert not (isolated_datastore / "baseline.json").exists()
    assert not (isolated_datastore / "user_preferences.json").exists()

    # Idempotent.
    again = run_migrations()
    assert again == {"applied": False, "moved": []}


def test_migration_leaves_new_file_when_both_exist(isolated_datastore: Path) -> None:
    (isolated_datastore / "state").mkdir(parents=True)
    (isolated_datastore / "state" / "baseline.json").write_text(
        '{"keep": true}', encoding="utf-8"
    )
    (isolated_datastore / "baseline.json").write_text('{"old": true}', encoding="utf-8")

    from engine.storage.migrate import run_migrations

    run_migrations()
    new_file = isolated_datastore / "state" / "baseline.json"
    assert json.loads(new_file.read_text()) == {"keep": True}
    # Stale legacy copy must be removed so future migrations don't trip on it.
    assert not (isolated_datastore / "baseline.json").exists()


def test_storage_summary_reports_paths_and_sizes(isolated_datastore: Path) -> None:
    from engine.storage.atomic import write_json_atomic
    from engine.storage.paths import (
        CACHE_DIR,
        CONFIG_DIR,
        ensure_layout,
        storage_summary,
    )

    ensure_layout()
    write_json_atomic(CONFIG_DIR / "x.json", {"k": "v"})
    (CACHE_DIR / "tmp.bin").write_bytes(b"\x00" * 1024)

    info = storage_summary()
    assert info["root"] == str(isolated_datastore)
    assert info["sections"]["config"]["bytes"] > 0
    assert info["sections"]["cache"]["bytes"] >= 1024
    assert info["total_bytes"] == sum(s["bytes"] for s in info["sections"].values())


def test_storage_dir_env_override_is_honored(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Engine should treat SENTRACORE_DATA_DIR as the writable root."""
    monkeypatch.setenv("SENTRACORE_DATA_DIR", str(tmp_path))
    for mod in ("engine.storage.paths", "engine.storage", "engine.config"):
        sys.modules.pop(mod, None)
    from engine.storage.paths import CONFIG_DIR

    assert CONFIG_DIR == tmp_path / "config"
    # No accidental writes happen yet.
    assert not any(p.name == "config" for p in tmp_path.iterdir())
    os.makedirs(CONFIG_DIR, exist_ok=True)
    assert CONFIG_DIR.is_dir()
