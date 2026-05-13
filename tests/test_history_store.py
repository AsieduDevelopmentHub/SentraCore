"""Tests for engine.history.history_store."""

from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest


@pytest.fixture()
def isolated(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("SENTRACORE_DATA_DIR", str(tmp_path))
    for mod in [
        "engine.history.history_store",
        "engine.history",
        "engine.storage.paths",
        "engine.storage",
        "engine.config",
    ]:
        sys.modules.pop(mod, None)
    return tmp_path


def _make_sample(at: float, cpu: float = 10.0):
    from engine.history.history_store import HistorySample

    return HistorySample(
        at=at,
        cpu_percent=cpu,
        mem_percent=20.0,
        disk_pressure_percent=5.0,
        stability_score=88.0,
        stress_score=12.0,
        top_processes=(),
    )


def test_record_writes_jsonl_with_one_line_per_sample(isolated: Path) -> None:
    from engine.history.history_store import HistoryStore

    store = HistoryStore(directory=isolated / "history", min_interval_sec=0)
    base = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc).timestamp()
    for i in range(3):
        assert store.record(_make_sample(base + i, cpu=float(i)))

    file = isolated / "history" / "samples-2026-01-01.jsonl"
    assert file.is_file()
    lines = file.read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == 3


def test_record_debounces_within_min_interval(isolated: Path) -> None:
    from engine.history.history_store import HistoryStore

    store = HistoryStore(directory=isolated / "history", min_interval_sec=10.0)
    base = datetime(2026, 1, 1, tzinfo=timezone.utc).timestamp()
    assert store.record(_make_sample(base))
    assert not store.record(_make_sample(base + 1))
    assert store.record(_make_sample(base + 11))


def test_query_filters_by_range_and_downsamples(isolated: Path) -> None:
    from engine.history.history_store import HistoryStore

    store = HistoryStore(directory=isolated / "history", min_interval_sec=0)
    base = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc).timestamp()
    for i in range(20):
        store.record(_make_sample(base + i, cpu=float(i)))

    everything = store.query(from_ts=base, to_ts=base + 19)
    assert len(everything) == 20

    windowed = store.query(from_ts=base + 5, to_ts=base + 9)
    assert [s["cpu_percent"] for s in windowed] == [5, 6, 7, 8, 9]

    downsampled = store.query(from_ts=base, to_ts=base + 19, granularity_sec=5)
    times = [s["at"] for s in downsampled]
    # Should keep the first sample and then one every >=5s.
    assert times[0] == base
    for a, b in zip(times, times[1:]):
        assert b - a >= 5


def test_retention_prunes_old_daily_files(isolated: Path) -> None:
    from engine.history.history_store import HistoryStore

    store = HistoryStore(
        directory=isolated / "history", min_interval_sec=0, retention_days=2
    )
    today = datetime.now(timezone.utc)
    old_day = today - timedelta(days=5)
    recent_day = today - timedelta(days=1)

    store.record(_make_sample(old_day.timestamp()))
    store.record(_make_sample(recent_day.timestamp()))
    store.record(_make_sample(today.timestamp()))

    files = sorted((isolated / "history").glob("samples-*.jsonl"))
    names = [f.name for f in files]
    assert f"samples-{old_day.date().isoformat()}.jsonl" not in names
    assert f"samples-{recent_day.date().isoformat()}.jsonl" in names
    assert f"samples-{today.date().isoformat()}.jsonl" in names


def test_clear_removes_every_history_file(isolated: Path) -> None:
    from engine.history.history_store import HistoryStore

    store = HistoryStore(directory=isolated / "history", min_interval_sec=0)
    base = datetime(2026, 2, 1, tzinfo=timezone.utc).timestamp()
    for i in range(3):
        store.record(_make_sample(base + i * 86_400))

    assert store.clear() == 3
    assert not any((isolated / "history").glob("samples-*.jsonl"))


def test_query_skips_malformed_lines(isolated: Path) -> None:
    from engine.history.history_store import HistoryStore

    history_dir = isolated / "history"
    history_dir.mkdir(parents=True, exist_ok=True)

    # Use today's date so retention does not prune the seeded file.
    today = datetime.now(timezone.utc)
    midnight = today.replace(hour=0, minute=0, second=0, microsecond=0)
    t0 = midnight.timestamp() + 60  # 00:01 UTC today
    t1 = t0 + 100

    f = history_dir / f"samples-{today.date().isoformat()}.jsonl"
    f.write_text(
        f'{{"at": {t0}, "cpu_percent": 10}}\n'
        "not json\n"
        f'{{"at": {t1}, "cpu_percent": 20}}\n',
        encoding="utf-8",
    )
    store = HistoryStore(directory=history_dir, min_interval_sec=0)
    out = store.query(from_ts=t0 - 1, to_ts=t1 + 1)
    cpus = [s["cpu_percent"] for s in out]
    assert cpus == [10, 20]
