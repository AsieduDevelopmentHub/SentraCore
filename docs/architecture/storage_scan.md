# Storage Scanning & Cleanup

The **Storage** tab in the desktop dashboard answers two questions the user
asks when their drive is full:

1. *"What can I safely delete right now?"* — the **Free up space** panel scans
   well-known cache and temp directories, previews how much space each bucket
   would free, and applies the cleanup with a Recycle-Bin or permanent-delete
   option.
2. *"Where is my disk space going?"* — the **Largest files** panel walks a
   user-chosen folder and surfaces the biggest files first, with a one-click
   "open containing folder" shortcut.

Both features live in `engine/storage_scan/` and are exposed via the local
REST API.

---

## Module layout

```text
engine/storage_scan/
├── __init__.py
├── cleanup_categories.py   # OS-aware "safe to clean" definitions
├── scanner.py              # walks categories, returns summary + scan_id
├── cleaner.py              # applies a previously-recorded scan
└── finder.py               # bounded "largest files under path" walker
```

Each module is intentionally small and pure: nothing in here mutates engine
state, and the cleanup itself is gated by a server-side handshake.

---

## Cleanup categories (`cleanup_categories.py`)

A *category* is one logical bucket of disposable files (for example, "Chrome
cache" or "User temporary files"). The module ships declarative definitions
for each OS:

| Platform | Categories |
|---|---|
| Windows | user temp, Windows Temp, Chrome / Edge / Firefox caches, pip / npm / Yarn caches, VS Code caches, Recycle Bin |
| Linux   | `~/.cache`, XDG trash, APT archives, pip / npm caches, thumbnails |
| macOS   | `~/Library/Caches`, `~/.Trash`, Xcode DerivedData, pip / npm caches |

Each `CleanupCategory` exposes:

* `roots` – one or more directories the scanner is *allowed* to walk.
* `min_age_days` – ignore files newer than this (e.g. avoid deleting a temp
  file an active app is still writing).
* `max_depth` – guard rail against deep junk trees.

`available_categories()` returns only the categories whose roots exist on the
current machine; the result is cached for the process lifetime.

---

## Scanner (`scanner.py`)

`run_scan(category_ids=None)` walks each selected category with three
bounds:

| Parameter | Default | Why |
|---|---|---|
| `max_files_per_category` | 25 000 | Prevents pathological folders from stalling the UI |
| `max_bytes_per_category` | 64 GiB | Same — caps wall time on huge caches |
| `sample_per_category` | 20 | Number of largest-file paths returned for preview |

Returned structure (also serialized by the API):

```json
{
  "scan_id": "f3c5…",
  "os": "windows",
  "total_bytes": 1234567890,
  "total_files": 1842,
  "categories": [
    {
      "id": "chrome_cache",
      "label": "Chrome cache",
      "bytes": 543210000,
      "file_count": 1100,
      "roots": ["C:\\Users\\…\\Chrome\\…\\Cache"],
      "samples": [{"path": "…", "size": 1048576, "mtime": 1736...}]
    }
  ]
}
```

### Why a `scan_id`?

Every scan registers its full candidate list (paths + sizes) in an
in-memory `ScanRegistry` keyed by `scan_id`. The cleaner refuses to delete
anything that doesn't appear in a stored scan — so the API cannot be tricked
into deleting an arbitrary path. The registry is bounded (16 scans) and TTL
(30 minutes) so stale results don't pile up.

---

## Cleaner (`cleaner.py`)

`apply_cleanup(scan_id, category_ids, mode)` walks the candidate list and
either:

* **`recycle`** (default): moves each file to the OS Recycle Bin / Trash via
  the optional [`send2trash`](https://pypi.org/project/send2trash/) package.
  If `send2trash` is not installed, the cleaner *does not* fall back silently
  — it returns `recycle` requests untouched and surfaces a UI hint.
* **`permanent`**: unlinks the file directly.

Before every deletion the cleaner re-validates the path against the
category's declared roots, so a symlink swap between scan and apply cannot
escape the safe zone. Locked files (common on Windows) raise `OSError`,
which is captured into the `errors` list on the response and counted as
`skipped` — never as `removed`.

---

## Large file finder (`finder.py`)

`find_large_files(root, min_size_mb, limit, max_files_scanned)` does a
non-recursive-into-OS walk:

* Excludes platform-specific system directories by default (`C:\Windows`,
  `/proc`, `/System`, etc.).
* Uses an O(`limit`) min-heap so memory stays flat even on huge drives.
* Stops after `max_files_scanned` file inspections (200 000 by default), so
  a user who points it at `C:\` doesn't accidentally pin the engine for
  minutes — they'll get partial results and a UI hint to narrow the path.

Each entry returns `path`, `size`, `mtime`, and `parent` — the parent path
powers the dashboard's "Open containing folder" button.

---

## REST API

| Method | Endpoint | Purpose |
|---|---|---|
| `GET`  | `/api/v1/cleanup/categories` | List categories available on this OS |
| `POST` | `/api/v1/cleanup/scan` | Run a scan; returns `scan_id` + summary |
| `GET`  | `/api/v1/cleanup/scan/{scan_id}` | Retrieve a previously-recorded scan |
| `POST` | `/api/v1/cleanup/apply` | Apply a scan; body `{scan_id, category_ids, mode}` |
| `GET`  | `/api/v1/storage/large?path=…&min_mb=…&limit=…` | Largest files under `path` |

The scan & apply endpoints are synchronous (`asyncio.to_thread`), so the
dashboard can drive them with a simple loading indicator. If scans ever
grow long enough to need background jobs, the registry already abstracts
the storage — a future `engine/jobs.py` can wrap `run_scan` without changing
the cleaner contract.

---

## Dashboard surface

* New navigation rail entry **Storage** (between *Diagnostics* and *Settings*).
* Two tabs:
  * **Free up space** — Scan now → per-category cards with checkbox, samples,
    and totals → "Move to Recycle Bin" / "Delete permanently" with
    confirmation.
  * **Largest files** — path input, min-size slider, max-results slider,
    sortable result list with "Open containing folder".
* `dashboard/lib/services/engine_service.dart` exposes:
  * `getCleanupCategories`, `runCleanupScan`, `applyCleanup`,
    `findLargeFiles`.

---

## Tests

`tests/test_storage_scan.py` covers:

* Scanner aggregation, min-age filtering, file-count cap, sample ordering.
* Cleaner rejection of unknown `scan_id` and unknown `mode`.
* Cleaner permanent-delete correctness.
* Cleaner refusing to delete paths that escape declared roots.
* Finder ordering, min-size filtering, scan cap, and excluded-roots
  filtering.
