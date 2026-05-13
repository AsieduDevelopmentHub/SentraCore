# Persistence Layout

The SentraCore engine keeps everything it learns about a machine on that machine, so that an unexpected stop (Task Manager kill, power loss, installer upgrade) does not wipe the baseline, alerts, or chart history. This document explains where the data lives, how it survives restarts, and what the operator can safely delete.

---

## On-disk root (`DATASTORE_DIR`)

The writable root is resolved at startup by `engine/config.py::_writable_datastore_dir()` in this order:

1. `SENTRACORE_DATA_DIR` environment variable (explicit override).
2. The package directory `engine/datastore/` if it is writable (development mode).
3. `%LOCALAPPDATA%/SentraCore/datastore` (Windows installs).
4. `~/.local/share/SentraCore/datastore` (other platforms).

`engine-config.json` (`host`, `port`, `status`, `pid`) lives **next to the engine executable** because the dashboard and the engine binary must agree on the listen address without reading the user's datastore. Everything else — preferences, baseline, history, logs — lives under `DATASTORE_DIR`.

---

## Grouped directory layout

```
<DATASTORE_DIR>/
├── config/      user preferences, future engine settings
├── state/       baseline, runtime checkpoint, migration marker
├── history/     daily-rotated JSONL telemetry samples
├── logs/        rotating engine.log (size-capped)
├── cache/       safe-to-delete derived artifacts
└── reports/     user-facing exported artifacts
```

The constants are defined in `engine/storage/paths.py`. `ensure_layout()` is called from `engine/main.py::main()` so the directories exist before any module tries to write.

### Migration from the legacy flat layout

Before v0.0.2 the engine wrote `baseline.json`, `user_preferences.json`, and `logs/engine.log` directly under `DATASTORE_DIR`. `engine/storage/migrate.py::run_migrations()` performs a one-shot, idempotent move on first startup:

* `baseline.json` &rarr; `state/baseline.json`
* `user_preferences.json` &rarr; `config/user_preferences.json`

A marker file at `state/.migrated_v1` records completion. If a file already exists in its new location, the legacy copy is simply removed so it cannot reintroduce stale data later.

---

## Atomic writes

Every JSON state file is written through `engine/storage/atomic.py::write_json_atomic()` — payload goes to a sibling temp file inside the destination directory, `fsync` is best-effort, and `os.replace` swaps the result into place. This means a crash during a write leaves either the previous valid file or the new one — never a half-written blob. Readers use `read_json()` which tolerates missing or malformed files (returns the caller's default), so a single corrupt file cannot prevent the engine from starting.

---

## History archive

`engine/history/history_store.py` records one downsampled telemetry sample at most every `HISTORY_SAMPLE_INTERVAL_SEC` (default 30 s). Files are JSONL, one sample per line, rotated by UTC day:

```
history/samples-2026-05-13.jsonl
history/samples-2026-05-14.jsonl
```

JSONL is used instead of a single big JSON document so:

* Append is O(1) and never re-encodes existing data.
* If the engine is killed mid-write, the next reader simply skips one malformed line instead of losing the archive.
* Retention pruning is trivial: delete whole files older than `HISTORY_RETENTION_DAYS` (default 30 days).

Server-side history is exposed at:

* `GET /api/v1/history?from=<unix>&to=<unix>&granularity=<sec>&limit=<n>` — returns samples between the given timestamps, optionally downsampled.
* `DELETE /api/v1/history` — wipes the archive.

The Flutter dashboard pulls this endpoint on connect and every minute thereafter (`HistoryProvider.startPeriodicRefresh`), with `SharedPreferences` acting only as an offline mirror.

---

## Runtime checkpoint

`engine/state/runtime_state.py` writes a small `state/runtime.json` containing:

* `last_clean_shutdown` (bool)
* `last_checkpoint_at` (UTC seconds)
* `alerts_recent` — most recent alerts
* `last_stress`, `last_stability`, `last_normalized`, `last_prediction`, `last_anomaly`

The engine flips `last_clean_shutdown` to `False` at startup and writes a fresh checkpoint every `RUNTIME_CHECKPOINT_INTERVAL_SEC` (default 30 s). On a clean stop the final write sets the flag back to `True`. On the next startup `SentraCoreEngine.get_current_state()` falls back to the checkpoint values until the engine produces a fresh reading, which means the dashboard's "Last alert", stability score, and recent breach list are populated immediately after a restart instead of going blank.

---

## Configurable retention / size limits

All defaults live in `engine/config.py` and respect environment-variable overrides:

| Setting | Env var | Default |
|---|---|---|
| History retention (days) | `SENTRACORE_HISTORY_RETENTION_DAYS` | 30 |
| History sample spacing (s) | `SENTRACORE_HISTORY_SAMPLE_INTERVAL_SEC` | 30 |
| Log file max bytes | `SENTRACORE_LOG_MAX_BYTES` | 2 MiB |
| Log rotation backups | `SENTRACORE_LOG_BACKUP_COUNT` | 5 |
| Runtime checkpoint cadence (s) | `SENTRACORE_RUNTIME_CHECKPOINT_INTERVAL_SEC` | 30 |
| Datastore root | `SENTRACORE_DATA_DIR` | platform-specific |

---

## REST surface

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/storage/info` | Sizes, paths, history summary, "previous run unclean" flag. |
| `POST /api/v1/storage/cache/clear` | Delete files under `cache/`. Never touches config/state/history. |
| `GET /api/v1/history` | Query history samples. |
| `DELETE /api/v1/history` | Wipe the history archive. |
| `POST /api/v1/state/reset/baseline` | Reset behavioral baseline; engine keeps running. |

The dashboard exposes the same controls under **Settings → Storage**: a one-click reveal of the data folder, current usage per subdirectory, and confirm-gated buttons for cache clear, history clear, and baseline reset.

---

## What is safe to delete by hand?

| Directory | Safe to delete? | Effect |
|---|---|---|
| `cache/` | Yes | Engine rebuilds as needed. |
| `logs/` | Yes | Loses past log lines only. |
| `reports/` | Yes | Loses any artifacts you previously exported. |
| `history/` | Yes, with intent | Loses long-term trend visualizations. |
| `state/` | No (unless reinstalling) | Loses baseline + last alerts + clean-shutdown flag. |
| `config/` | No | Loses your preferences. |
