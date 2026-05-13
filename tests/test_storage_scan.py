"""Unit tests for engine.storage_scan: scanner, cleaner, finder, categories."""

from __future__ import annotations

import os
import time
from pathlib import Path

import pytest

from engine.storage_scan import cleaner as cleaner_mod
from engine.storage_scan import cleanup_categories as cats_mod
from engine.storage_scan import finder as finder_mod
from engine.storage_scan import scanner as scanner_mod
from engine.storage_scan.cleanup_categories import CleanupCategory


def _make_files(
    root: Path, sizes: list[int], *, ages_days: list[int] | None = None
) -> list[Path]:
    """Create files under ``root`` with the given sizes and optional ages."""
    root.mkdir(parents=True, exist_ok=True)
    out: list[Path] = []
    now = time.time()
    for i, size in enumerate(sizes):
        p = root / f"f{i}.bin"
        p.write_bytes(b"\0" * size)
        if ages_days is not None:
            age = ages_days[i]
            ts = now - (age * 86_400)
            os.utime(p, (ts, ts))
        out.append(p)
    return out


@pytest.fixture(autouse=True)
def _isolate_scan_registry(monkeypatch: pytest.MonkeyPatch):
    """Replace the global scan registry with a fresh one per test."""
    fresh = scanner_mod.ScanRegistry()
    monkeypatch.setattr(scanner_mod, "_registry", fresh)
    yield


def _install_category(monkeypatch: pytest.MonkeyPatch, cat: CleanupCategory) -> None:
    """Force ``available_categories()`` to return exactly the given category."""
    monkeypatch.setattr(cats_mod, "_CATEGORIES_CACHE", [cat])


# --------------------------------------------------------------------------- #
# Scanner
# --------------------------------------------------------------------------- #


def test_scanner_aggregates_files(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_files(tmp_path / "junk", [10, 20, 30])
    cat = CleanupCategory(
        id="test_cat",
        label="Test",
        description="",
        roots=(tmp_path / "junk",),
    )
    _install_category(monkeypatch, cat)

    result = scanner_mod.run_scan(["test_cat"])

    assert result.total_files == 3
    assert result.total_bytes == 60
    assert len(result.categories) == 1
    assert result.categories[0].file_count == 3
    # Scan should be stored in the registry, keyed by scan_id.
    assert scanner_mod.scan_registry().get(result.scan_id) is not None


def test_scanner_respects_min_age(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_files(
        tmp_path / "junk",
        [100, 200, 300],
        ages_days=[0, 5, 10],
    )
    cat = CleanupCategory(
        id="aged",
        label="Aged",
        description="",
        roots=(tmp_path / "junk",),
        min_age_days=3,
    )
    _install_category(monkeypatch, cat)

    result = scanner_mod.run_scan(["aged"])
    # Only the 200 + 300 byte files are old enough.
    assert result.total_files == 2
    assert result.total_bytes == 500


def test_scanner_caps_file_count(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_files(tmp_path / "junk", [1] * 50)
    cat = CleanupCategory(
        id="big",
        label="Big",
        description="",
        roots=(tmp_path / "junk",),
    )
    _install_category(monkeypatch, cat)

    result = scanner_mod.run_scan(
        ["big"],
        max_files_per_category=10,
    )
    assert result.total_files == 10


def test_scanner_samples_largest_first(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    sizes = [10, 5_000, 250, 100, 9_999]
    _make_files(tmp_path / "junk", sizes)
    cat = CleanupCategory(
        id="samples",
        label="S",
        description="",
        roots=(tmp_path / "junk",),
    )
    _install_category(monkeypatch, cat)

    result = scanner_mod.run_scan(["samples"], sample_per_category=3)
    sample_sizes = [s["size"] for s in result.categories[0].samples]
    assert sample_sizes == sorted(sample_sizes, reverse=True)
    assert sample_sizes[0] == 9_999


# --------------------------------------------------------------------------- #
# Cleaner
# --------------------------------------------------------------------------- #


def test_cleaner_requires_known_scan_id() -> None:
    with pytest.raises(KeyError):
        cleaner_mod.apply_cleanup(
            scan_id="does-not-exist",
            category_ids=None,
            mode="permanent",
        )


def test_cleaner_rejects_unknown_mode(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_files(tmp_path / "junk", [1, 2, 3])
    cat = CleanupCategory(
        id="x",
        label="X",
        description="",
        roots=(tmp_path / "junk",),
    )
    _install_category(monkeypatch, cat)
    scan = scanner_mod.run_scan(["x"])
    with pytest.raises(ValueError):
        cleaner_mod.apply_cleanup(
            scan_id=scan.scan_id,
            category_ids=["x"],
            mode="nuke-from-orbit",
        )


def test_cleaner_permanent_removes_files(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    files = _make_files(tmp_path / "junk", [100, 200, 300])
    cat = CleanupCategory(
        id="p",
        label="P",
        description="",
        roots=(tmp_path / "junk",),
    )
    _install_category(monkeypatch, cat)
    scan = scanner_mod.run_scan(["p"])

    result = cleaner_mod.apply_cleanup(
        scan_id=scan.scan_id,
        category_ids=["p"],
        mode=cleaner_mod.CLEAN_MODE_PERMANENT,
    )

    assert result.removed == 3
    assert result.bytes_freed == 600
    for f in files:
        assert not f.exists()


def test_cleaner_skips_paths_outside_roots(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_files(tmp_path / "junk", [10])
    cat = CleanupCategory(
        id="r",
        label="R",
        description="",
        roots=(tmp_path / "junk",),
    )
    _install_category(monkeypatch, cat)
    scan = scanner_mod.run_scan(["r"])

    # Tamper with a candidate so its path falls outside the declared roots.
    outside = tmp_path / "outside.bin"
    outside.write_bytes(b"hello")
    cands = scan.candidates["r"]
    cands.append(
        scanner_mod._ScanCandidate(
            path=str(outside),
            size=outside.stat().st_size,
            mtime=outside.stat().st_mtime,
            category_id="r",
        )
    )

    result = cleaner_mod.apply_cleanup(
        scan_id=scan.scan_id,
        category_ids=["r"],
        mode=cleaner_mod.CLEAN_MODE_PERMANENT,
    )

    # The legitimate file is gone; the tampered candidate was skipped.
    assert not (tmp_path / "junk" / "f0.bin").exists()
    assert outside.exists()
    assert result.skipped >= 1


# --------------------------------------------------------------------------- #
# Finder
# --------------------------------------------------------------------------- #


def test_finder_returns_largest_first(tmp_path: Path) -> None:
    files = _make_files(
        tmp_path / "files",
        [10 * 1024 * 1024, 5 * 1024 * 1024, 50 * 1024 * 1024],
    )
    items = finder_mod.find_large_files(
        tmp_path,
        min_size_mb=1.0,
        limit=10,
        excluded_roots=set(),
    )
    sizes = [i.size for i in items]
    assert sizes == sorted(sizes, reverse=True)
    assert items[0].size == files[2].stat().st_size


def test_finder_filters_by_min_size(tmp_path: Path) -> None:
    _make_files(
        tmp_path / "files",
        [1 * 1024 * 1024, 50 * 1024 * 1024, 100 * 1024 * 1024],
    )
    items = finder_mod.find_large_files(
        tmp_path,
        min_size_mb=40.0,
        limit=10,
        excluded_roots=set(),
    )
    assert len(items) == 2
    assert all(i.size >= 40 * 1024 * 1024 for i in items)


def test_finder_caps_scan_count(tmp_path: Path) -> None:
    _make_files(tmp_path / "many", [10 * 1024 * 1024] * 50)
    items = finder_mod.find_large_files(
        tmp_path,
        min_size_mb=1.0,
        limit=500,
        max_files_scanned=5,
        excluded_roots=set(),
    )
    # Result is bounded by the scan cap, not the number of matches.
    assert len(items) <= 5


def test_finder_skips_excluded_roots(tmp_path: Path) -> None:
    _make_files(tmp_path / "ok", [100 * 1024 * 1024])
    _make_files(tmp_path / "ignored", [200 * 1024 * 1024])
    items = finder_mod.find_large_files(
        tmp_path,
        min_size_mb=1.0,
        limit=10,
        excluded_roots={str((tmp_path / "ignored").resolve()).lower()},
    )
    paths = [i.path.lower() for i in items]
    assert any("ok" in p for p in paths)
    assert all("ignored" not in p for p in paths)
