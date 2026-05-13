"""
SentraCore — Engine-owned telemetry history.

Each persisted sample is one JSON object on its own line in a daily-rotated
file (``samples-YYYY-MM-DD.jsonl``). JSONL is used instead of a single big
JSON document because:

* Append is O(1) and never requires re-encoding existing data.
* A corrupted last line (engine killed mid-write) costs us one sample, not
  the entire archive — readers simply skip malformed lines.
* Retention pruning is trivial: delete whole files older than the policy.

The store is intentionally small. It supports recording one sample (with
optional top-N processes) and querying a time range with optional
granularity-based downsampling for chart rendering.
"""

from __future__ import annotations

import json
import logging
import threading
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

from engine.config import (
    HISTORY_RETENTION_DAYS,
    HISTORY_SAMPLE_INTERVAL_SEC,
    HISTORY_SUBDIR,
)

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class HistoryProcessSample:
    """Top-N process snapshot for a single history sample."""

    name: str
    pid: int
    cpu_percent: float
    mem_percent: float
    impact: float

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "pid": int(self.pid),
            "cpu_percent": round(float(self.cpu_percent), 2),
            "mem_percent": round(float(self.mem_percent), 2),
            "impact": round(float(self.impact), 2),
        }


@dataclass(frozen=True, slots=True)
class HistorySample:
    """One persisted telemetry datapoint."""

    at: float  # POSIX seconds
    cpu_percent: float
    mem_percent: float
    disk_pressure_percent: float
    stability_score: float | None = None
    stress_score: float | None = None
    top_processes: tuple[HistoryProcessSample, ...] = field(default_factory=tuple)

    def to_dict(self) -> dict:
        return {
            "at": float(self.at),
            "cpu_percent": round(float(self.cpu_percent), 2),
            "mem_percent": round(float(self.mem_percent), 2),
            "disk_pressure_percent": round(float(self.disk_pressure_percent), 2),
            "stability_score": (
                round(float(self.stability_score), 2)
                if self.stability_score is not None
                else None
            ),
            "stress_score": (
                round(float(self.stress_score), 2)
                if self.stress_score is not None
                else None
            ),
            "top_processes": [p.to_dict() for p in self.top_processes],
        }


def _day_filename(day: datetime) -> str:
    return f"samples-{day.strftime('%Y-%m-%d')}.jsonl"


def _utc_midnight(at: datetime) -> datetime:
    return at.replace(hour=0, minute=0, second=0, microsecond=0)


class HistoryStore:
    """Append-only, daily-rotated history of system samples.

    Thread-safe via a single :class:`threading.Lock`; the engine's async loop
    appends from a single task, but external callers (API, tests) may also
    invoke the store directly.
    """

    def __init__(
        self,
        directory: Path = HISTORY_SUBDIR,
        retention_days: int = HISTORY_RETENTION_DAYS,
        min_interval_sec: float = HISTORY_SAMPLE_INTERVAL_SEC,
    ) -> None:
        self._dir = directory
        self._retention_days = max(1, int(retention_days))
        self._min_interval = max(0.5, float(min_interval_sec))
        self._lock = threading.Lock()
        self._last_at: float = 0.0
        self._dir.mkdir(parents=True, exist_ok=True)
        self._prune_old(reference=datetime.now(timezone.utc))

    # ------------------------------------------------------------------ write

    def record(self, sample: HistorySample) -> bool:
        """Persist ``sample`` if at least :attr:`min_interval_sec` has elapsed.

        Returns ``True`` if the sample was written, ``False`` if it was
        debounced.
        """
        with self._lock:
            if sample.at - self._last_at < self._min_interval:
                return False
            day = datetime.fromtimestamp(sample.at, tz=timezone.utc)
            path = self._dir / _day_filename(day)
            line = json.dumps(sample.to_dict(), separators=(",", ":"))
            try:
                with path.open("a", encoding="utf-8") as f:
                    f.write(line)
                    f.write("\n")
            except OSError as exc:
                logger.warning("history: failed to append to %s: %s", path, exc)
                return False
            self._last_at = sample.at
            self._prune_old(reference=day)
            return True

    # ------------------------------------------------------------------ read

    def query(
        self,
        *,
        from_ts: float | None = None,
        to_ts: float | None = None,
        granularity_sec: float | None = None,
        limit: int | None = None,
    ) -> list[dict]:
        """Return samples between ``from_ts`` and ``to_ts`` (inclusive).

        ``granularity_sec`` downsamples by skipping points closer together than
        the requested spacing — useful for rendering large ranges. ``limit``
        caps the returned list to the most recent N samples after downsampling.
        """
        now = datetime.now(timezone.utc).timestamp()
        if to_ts is None:
            to_ts = now
        if from_ts is None:
            from_ts = to_ts - 24 * 3600

        if from_ts > to_ts:
            from_ts, to_ts = to_ts, from_ts

        from_day = datetime.fromtimestamp(from_ts, tz=timezone.utc).date()
        to_day = datetime.fromtimestamp(to_ts, tz=timezone.utc).date()

        days = []
        cur = from_day
        while cur <= to_day:
            days.append(cur)
            cur = cur + timedelta(days=1)

        out: list[dict] = []
        last_emitted: float | None = None
        gran = max(0.0, float(granularity_sec or 0.0))
        for d in days:
            path = self._dir / f"samples-{d.isoformat()}.jsonl"
            if not path.is_file():
                continue
            try:
                with path.open("r", encoding="utf-8") as f:
                    for raw in f:
                        raw = raw.strip()
                        if not raw:
                            continue
                        try:
                            obj = json.loads(raw)
                        except json.JSONDecodeError:
                            continue
                        try:
                            at = float(obj.get("at"))
                        except (TypeError, ValueError):
                            continue
                        if at < from_ts or at > to_ts:
                            continue
                        if (
                            gran
                            and last_emitted is not None
                            and at - last_emitted < gran
                        ):
                            continue
                        out.append(obj)
                        last_emitted = at
            except OSError as exc:
                logger.debug("history: read %s: %s", path, exc)
                continue

        out.sort(key=lambda x: x.get("at", 0))
        if limit is not None and limit > 0 and len(out) > limit:
            out = out[-int(limit) :]
        return out

    # --------------------------------------------------------------- summary

    def summary(self) -> dict:
        """Return on-disk facts about the history archive."""
        files = sorted(self._dir.glob("samples-*.jsonl"))
        total_bytes = 0
        total_lines = 0
        for f in files:
            try:
                total_bytes += f.stat().st_size
            except OSError:
                continue
            try:
                with f.open("rb") as fh:
                    for _ in fh:
                        total_lines += 1
            except OSError:
                continue
        return {
            "directory": str(self._dir),
            "retention_days": self._retention_days,
            "min_interval_sec": self._min_interval,
            "files": [str(f.name) for f in files],
            "total_bytes": total_bytes,
            "total_samples": total_lines,
        }

    def clear(self) -> int:
        """Delete every history file. Returns the count removed."""
        removed = 0
        with self._lock:
            for f in self._dir.glob("samples-*.jsonl"):
                try:
                    f.unlink()
                    removed += 1
                except OSError as exc:
                    logger.debug("history: unlink %s: %s", f, exc)
            self._last_at = 0.0
        return removed

    # -------------------------------------------------------------- internal

    def _prune_old(self, *, reference: datetime) -> None:
        """Delete daily files older than the retention horizon."""
        cutoff_day = _utc_midnight(reference) - timedelta(days=self._retention_days)
        for f in self._dir.glob("samples-*.jsonl"):
            stem = f.stem.removeprefix("samples-")
            try:
                day = datetime.strptime(stem, "%Y-%m-%d").replace(tzinfo=timezone.utc)
            except ValueError:
                continue
            if day < cutoff_day:
                try:
                    f.unlink()
                except OSError as exc:
                    logger.debug("history: prune %s: %s", f, exc)


def build_history_sample(
    *,
    at: float,
    cpu_percent: float,
    mem_percent: float,
    disk_pressure_percent: float,
    stability_score: float | None,
    stress_score: float | None,
    top_processes: Iterable[HistoryProcessSample] = (),
) -> HistorySample:
    """Convenience constructor used by the engine main loop."""
    return HistorySample(
        at=float(at),
        cpu_percent=float(cpu_percent),
        mem_percent=float(mem_percent),
        disk_pressure_percent=float(disk_pressure_percent),
        stability_score=stability_score
        if stability_score is None
        else float(stability_score),
        stress_score=stress_score if stress_score is None else float(stress_score),
        top_processes=tuple(top_processes),
    )
