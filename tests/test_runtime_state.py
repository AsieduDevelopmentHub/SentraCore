"""Tests for engine.state.runtime_state."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest


@pytest.fixture()
def isolated(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("SENTRACORE_DATA_DIR", str(tmp_path))
    for mod in [
        "engine.state.runtime_state",
        "engine.state",
        "engine.storage.paths",
        "engine.storage",
        "engine.config",
    ]:
        sys.modules.pop(mod, None)
    return tmp_path


def test_checkpoint_roundtrip(isolated: Path) -> None:
    from engine.state.runtime_state import RuntimeCheckpoint

    ckpt = RuntimeCheckpoint(path=isolated / "state" / "runtime.json")
    ckpt.write(
        alerts_recent=[{"timestamp": 1.0, "message": "hello"}],
        last_stress={"score": 42},
        last_stability={"score": 80},
        last_normalized={"cpu": {"smoothed": 12}},
        last_prediction={"risk_score": 5},
        last_anomaly={"score": 1},
        clean_shutdown=True,
    )
    data = ckpt.load()
    assert data["last_clean_shutdown"] is True
    assert data["alerts_recent"][0]["message"] == "hello"
    assert data["last_stress"]["score"] == 42


def test_unclean_previous_run_is_detected(isolated: Path) -> None:
    from engine.state.runtime_state import RuntimeCheckpoint

    path = isolated / "state" / "runtime.json"
    ckpt = RuntimeCheckpoint(path=path)
    # First boot: no file at all → previous looks unclean.
    assert ckpt.mark_dirty_startup() is True

    # Clean shutdown writes flag=True.
    ckpt.write(
        alerts_recent=[],
        last_stress=None,
        last_stability=None,
        last_normalized=None,
        last_prediction=None,
        last_anomaly=None,
        clean_shutdown=True,
    )
    # On the next startup the previous shutdown is clean.
    ckpt2 = RuntimeCheckpoint(path=path)
    assert ckpt2.mark_dirty_startup() is False


def test_load_tolerates_missing_or_corrupt_file(isolated: Path) -> None:
    from engine.state.runtime_state import RuntimeCheckpoint

    ckpt = RuntimeCheckpoint(path=isolated / "state" / "missing.json")
    data = ckpt.load()
    assert data["alerts_recent"] == []
    assert data["last_clean_shutdown"] is False

    corrupt = isolated / "state" / "broken.json"
    corrupt.parent.mkdir(parents=True, exist_ok=True)
    corrupt.write_text("{not json", encoding="utf-8")
    ckpt2 = RuntimeCheckpoint(path=corrupt)
    assert ckpt2.load()["alerts_recent"] == []
