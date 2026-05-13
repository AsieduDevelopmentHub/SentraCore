import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sentracore_dashboard/models/history_sample.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/services/engine_service.dart';

/// History samples ultimately live with the engine (persisted under
/// ``history/`` next to the rest of its datastore). This provider:
///
/// * Pulls authoritative samples from the engine via `/api/v1/history`.
/// * Keeps a small `SharedPreferences` mirror so charts still render when the
///   engine is offline (e.g. during the first second of dashboard startup or
///   while the engine restarts).
/// * Records live samples opportunistically — the data is rolled into the
///   offline mirror but the engine remains the source of truth across
///   restarts.
class HistoryProvider extends ChangeNotifier {
  static const _kHistorySamples = 'history_samples_v2';

  /// Local downsample cadence (engine pushes every ~2s).
  static const Duration sampleInterval = Duration(seconds: 30);

  /// Hard cap for the offline mirror; the server-side archive holds the rest.
  static const int maxSamples = 12000;

  /// How often we re-fetch from the engine while it is connected.
  static const Duration _refreshInterval = Duration(minutes: 1);

  /// How far back we ask the engine for on each refresh.
  static const Duration _refreshWindow = Duration(days: 7);

  final List<HistorySample> _samples = [];
  bool _loaded = false;
  DateTime? _lastSampleAt;
  Timer? _saveDebounce;

  /// When `true`, _samples reflects data pulled from the engine and is the
  /// source of truth. Local appends from [recordIfDue] still augment it
  /// between server refreshes.
  bool _syncedFromEngine = false;

  List<HistorySample> get samples => List<HistorySample>.unmodifiable(_samples);
  bool get loaded => _loaded;

  /// True once we've populated samples from the engine since launch.
  bool get syncedFromEngine => _syncedFromEngine;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kHistorySamples);
    if (raw == null || raw.trim().isEmpty) {
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _samples
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
                  (m) => HistorySample.fromJson(Map<String, dynamic>.from(m)),
                ),
          );
        _samples.sort((a, b) => a.at.compareTo(b.at));
        _lastSampleAt = _samples.isNotEmpty ? _samples.last.at : null;
      }
    } catch (_) {
      // Corrupt payload -> start clean.
      _samples.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  void clear() {
    _samples.clear();
    _lastSampleAt = null;
    _syncedFromEngine = false;
    notifyListeners();
    _scheduleSave();
  }

  /// Pull the persistent server-side archive and replace local samples with
  /// it. Falls back silently if the engine is unreachable so we keep showing
  /// the offline mirror.
  Future<void> refreshFromEngine(EngineService service,
      {Duration? window}) async {
    final now = DateTime.now();
    final from = now.subtract(window ?? _refreshWindow);
    final raw = await service.getHistory(
      from: from,
      to: now,
      // Engine collects at 30s spacing; granularity matches so we don't waste
      // bytes on near-duplicate samples for long ranges.
      granularitySec: 30.0,
      limit: maxSamples,
    );
    if (raw.isEmpty) return;

    final parsed = <HistorySample>[];
    for (final m in raw) {
      final at = m['at'];
      DateTime when;
      if (at is num) {
        when = DateTime.fromMillisecondsSinceEpoch(
          (at.toDouble() * 1000).round(),
        );
      } else {
        continue;
      }
      parsed.add(
        HistorySample(
          at: when,
          cpuPercent: (m['cpu_percent'] as num?)?.toDouble() ?? 0,
          memPercent: (m['mem_percent'] as num?)?.toDouble() ?? 0,
          diskPressurePercent:
              (m['disk_pressure_percent'] as num?)?.toDouble() ?? 0,
          topProcesses: _parseEngineProcesses(m['top_processes']),
        ),
      );
    }
    if (parsed.isEmpty) return;

    parsed.sort((a, b) => a.at.compareTo(b.at));
    _samples
      ..clear()
      ..addAll(parsed);
    _lastSampleAt = parsed.last.at;
    _syncedFromEngine = true;
    notifyListeners();
    _scheduleSave();
  }

  Timer? _refreshTimer;

  /// Begin periodically pulling from the engine. Safe to call repeatedly.
  void startPeriodicRefresh(EngineService service) {
    _refreshTimer?.cancel();
    // Fire an immediate refresh then continue on the interval.
    unawaited(refreshFromEngine(service));
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => unawaited(refreshFromEngine(service)),
    );
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  static List<HistoryProcessSample> _parseEngineProcesses(dynamic raw) {
    if (raw is! List) return const [];
    final out = <HistoryProcessSample>[];
    for (final m in raw) {
      if (m is! Map) continue;
      out.add(
        HistoryProcessSample(
          name: '${m['name'] ?? ''}',
          pid: (m['pid'] as num?)?.toInt() ?? 0,
          cpuPercent: (m['cpu_percent'] as num?)?.toDouble() ?? 0,
          memPercent: (m['mem_percent'] as num?)?.toDouble() ?? 0,
          impact: (m['impact'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return out;
  }

  /// Called by EngineProvider on every live state; this function decides whether
  /// we should record a new sample based on [sampleInterval].
  void recordIfDue({
    required DateTime now,
    required SystemState state,
    required List<ProcessImpact> processes,
  }) {
    final n = state.normalized;
    if (n == null) return;

    final last = _lastSampleAt;
    if (last != null && now.difference(last) < sampleInterval) return;

    final diskPct =
        ((n.diskIo.totalOpsPerSec) / 500.0 * 100.0).clamp(0.0, 100.0);
    final top = List<ProcessImpact>.from(processes)
      ..sort((a, b) => b.impactScore.compareTo(a.impactScore));
    final top10 = top.take(10).map((p) {
      return HistoryProcessSample(
        name: p.name,
        pid: p.pid,
        cpuPercent: p.cpuImpact,
        memPercent: p.memoryPercent,
        impact: p.impactScore,
      );
    }).toList();

    _samples.add(
      HistorySample(
        at: now,
        cpuPercent: n.cpu.smoothed.clamp(0.0, 100.0).toDouble(),
        memPercent: n.memory.smoothed.clamp(0.0, 100.0).toDouble(),
        diskPressurePercent: diskPct.toDouble(),
        topProcesses: top10,
      ),
    );
    _samples.sort((a, b) => a.at.compareTo(b.at));
    _lastSampleAt = now;

    // Retain only the newest maxSamples.
    if (_samples.length > maxSamples) {
      _samples.removeRange(0, _samples.length - maxSamples);
    }

    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_saveNow());
    });
  }

  Future<void> _saveNow() async {
    final p = await SharedPreferences.getInstance();
    final payload = jsonEncode(_samples.map((s) => s.toJson()).toList());
    await p.setString(_kHistorySamples, payload);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }
}
