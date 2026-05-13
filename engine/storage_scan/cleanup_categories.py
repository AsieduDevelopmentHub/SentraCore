"""
Declarative, OS-aware safe-to-clean targets.

Each :class:`CleanupCategory` lists one or more directory roots, a description,
and policy knobs (max age, follow-symlinks, recursive). The scanner walks each
root; the cleaner only deletes files whose absolute path lies under one of the
declared roots and whose presence was confirmed by a previous scan.

Adding a new category should be a config-only change — never reach into
operating-system internals here. The goal is "safe-to-delete by default" with
no surprises (we never recurse into a directory that could plausibly hold
user-created content).
"""

from __future__ import annotations

import os
import platform
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True, slots=True)
class CleanupCategory:
    """One bucket of "safe to delete" files.

    ``roots`` are expanded paths the scanner may walk. Items are kept only when
    every parent directory still resolves to one of these roots (no symlink
    escape).
    """

    id: str
    label: str
    description: str
    roots: tuple[Path, ...]
    min_age_days: int = 0  # Only consider files at least this old
    max_depth: int = 12
    requires_admin: bool = False
    extensions: tuple[str, ...] = field(default_factory=tuple)


def _existing(*candidates: str | None) -> tuple[Path, ...]:
    out: list[Path] = []
    for c in candidates:
        if not c:
            continue
        try:
            p = Path(os.path.expandvars(os.path.expanduser(c))).resolve()
        except OSError:
            continue
        if p.exists() and p.is_dir():
            out.append(p)
    return tuple(out)


def _is_windows() -> bool:
    return sys.platform == "win32"


def _is_macos() -> bool:
    return sys.platform == "darwin"


def _is_linux() -> bool:
    return sys.platform.startswith("linux")


def _windows_categories() -> list[CleanupCategory]:
    local = os.environ.get("LOCALAPPDATA")
    appdata = os.environ.get("APPDATA")
    user_profile = os.environ.get("USERPROFILE")
    win_dir = os.environ.get("WINDIR", r"C:\Windows")

    cats: list[CleanupCategory] = [
        CleanupCategory(
            id="user_temp",
            label="User temporary files",
            description="Files in your user TEMP folder, older than 1 day.",
            roots=_existing(os.environ.get("TEMP"), os.environ.get("TMP")),
            min_age_days=1,
        ),
        CleanupCategory(
            id="windows_temp",
            label="Windows Temp folder",
            description=(
                "Windows-wide temporary files. Some items may be locked; only "
                "user-owned files are removed."
            ),
            roots=_existing(f"{win_dir}\\Temp"),
            min_age_days=2,
        ),
        CleanupCategory(
            id="chrome_cache",
            label="Chrome cache",
            description="Google Chrome HTTP cache (does not touch cookies or history).",
            roots=_existing(
                f"{local}\\Google\\Chrome\\User Data\\Default\\Cache",
                f"{local}\\Google\\Chrome\\User Data\\Default\\Code Cache",
            ),
        ),
        CleanupCategory(
            id="edge_cache",
            label="Microsoft Edge cache",
            description="Microsoft Edge HTTP cache.",
            roots=_existing(
                f"{local}\\Microsoft\\Edge\\User Data\\Default\\Cache",
                f"{local}\\Microsoft\\Edge\\User Data\\Default\\Code Cache",
            ),
        ),
        CleanupCategory(
            id="firefox_cache",
            label="Firefox cache",
            description="Mozilla Firefox HTTP cache.",
            roots=_existing(f"{appdata}\\Mozilla\\Firefox\\Profiles"),
        ),
        CleanupCategory(
            id="pip_cache",
            label="pip wheel cache",
            description="Pip downloads; safe to remove (will redownload on next install).",
            roots=_existing(f"{local}\\pip\\Cache"),
        ),
        CleanupCategory(
            id="npm_cache",
            label="npm cache",
            description="npm package cache.",
            roots=_existing(
                f"{appdata}\\npm-cache",
                f"{user_profile}\\.npm",
            ),
        ),
        CleanupCategory(
            id="yarn_cache",
            label="Yarn cache",
            description="Yarn classic + Berry caches.",
            roots=_existing(
                f"{local}\\Yarn\\Cache",
                f"{user_profile}\\AppData\\Local\\Yarn\\Cache",
            ),
        ),
        CleanupCategory(
            id="vscode_cache",
            label="VS Code derived data",
            description="VS Code generated caches (does not touch settings).",
            roots=_existing(
                f"{appdata}\\Code\\CachedData",
                f"{appdata}\\Code\\Code Cache",
                f"{appdata}\\Code\\GPUCache",
            ),
        ),
        CleanupCategory(
            id="recycle_bin",
            label="Recycle Bin",
            description="Items in the Recycle Bin. Permanently emptied.",
            roots=_existing(
                f"{user_profile}\\$Recycle.Bin",
                "C:\\$Recycle.Bin",
            ),
        ),
    ]
    return [c for c in cats if c.roots]


def _linux_categories() -> list[CleanupCategory]:
    home = str(Path.home())
    return [
        c
        for c in [
            CleanupCategory(
                id="user_cache",
                label="User cache (~/.cache)",
                description="Application caches under your home directory.",
                roots=_existing(f"{home}/.cache"),
            ),
            CleanupCategory(
                id="trash",
                label="Trash",
                description="Items in your XDG trash bin.",
                roots=_existing(f"{home}/.local/share/Trash"),
            ),
            CleanupCategory(
                id="apt_cache",
                label="APT archives",
                description="Downloaded .deb packages (apt-get clean territory).",
                roots=_existing("/var/cache/apt/archives"),
                requires_admin=True,
            ),
            CleanupCategory(
                id="pip_cache",
                label="pip cache",
                description="Pip downloads; safe to remove.",
                roots=_existing(f"{home}/.cache/pip"),
            ),
            CleanupCategory(
                id="npm_cache",
                label="npm cache",
                description="npm package cache.",
                roots=_existing(f"{home}/.npm"),
            ),
            CleanupCategory(
                id="thumbnails",
                label="Thumbnail cache",
                description="GTK / GNOME thumbnail cache.",
                roots=_existing(f"{home}/.cache/thumbnails"),
            ),
        ]
        if c.roots
    ]


def _macos_categories() -> list[CleanupCategory]:
    home = str(Path.home())
    return [
        c
        for c in [
            CleanupCategory(
                id="user_cache",
                label="User caches (~/Library/Caches)",
                description="Application caches under your home Library folder.",
                roots=_existing(f"{home}/Library/Caches"),
            ),
            CleanupCategory(
                id="trash",
                label="Trash",
                description="Items in ~/.Trash.",
                roots=_existing(f"{home}/.Trash"),
            ),
            CleanupCategory(
                id="xcode_derived",
                label="Xcode DerivedData",
                description="Xcode build intermediates; safe to remove between builds.",
                roots=_existing(f"{home}/Library/Developer/Xcode/DerivedData"),
            ),
            CleanupCategory(
                id="pip_cache",
                label="pip cache",
                description="Pip downloads; safe to remove.",
                roots=_existing(f"{home}/Library/Caches/pip"),
            ),
            CleanupCategory(
                id="npm_cache",
                label="npm cache",
                description="npm package cache.",
                roots=_existing(f"{home}/.npm"),
            ),
        ]
        if c.roots
    ]


_CATEGORIES_CACHE: list[CleanupCategory] | None = None


def available_categories() -> list[CleanupCategory]:
    """Return the cleanup categories applicable to the current OS.

    The result is cached for the lifetime of the process. Removed because the
    cache makes the first call O(N) and subsequent calls O(1), and the
    underlying environment variables do not change at runtime.
    """
    global _CATEGORIES_CACHE
    if _CATEGORIES_CACHE is not None:
        return _CATEGORIES_CACHE

    if _is_windows():
        cats = _windows_categories()
    elif _is_macos():
        cats = _macos_categories()
    elif _is_linux():
        cats = _linux_categories()
    else:
        cats = []
    _CATEGORIES_CACHE = cats
    return cats


def get_category(category_id: str) -> CleanupCategory | None:
    for c in available_categories():
        if c.id == category_id:
            return c
    return None


def os_label() -> str:
    """Short label used in API responses ("windows", "linux", "macos")."""
    if _is_windows():
        return "windows"
    if _is_macos():
        return "macos"
    if _is_linux():
        return "linux"
    return platform.system().lower() or "unknown"


def reset_category_cache_for_tests() -> None:
    """Test helper — wipe the categories cache so env changes take effect."""
    global _CATEGORIES_CACHE
    _CATEGORIES_CACHE = None
