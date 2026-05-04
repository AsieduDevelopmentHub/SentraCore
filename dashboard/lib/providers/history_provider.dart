import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sentracore_dashboard/models/history_sample.dart';
import 'package:sentracore_dashboard/models/system_state.dart';

class HistoryProvider extends ChangeNotifier {
  static const _kHistorySamples = 'history_samples_v1';

  /// Default sampling cadence (engine pushes every ~2s; we downsample to keep storage sane).
  static const Duration sampleInterval = Duration(seconds: 30);

  /// Hard cap to prevent unbounded growth in SharedPreferences.
  static const int maxSamples =
      12000; // ~4 days at 30s; UI ranges use downsampling

  final List<HistorySample> _samples = [];
  bool _loaded = false;
  DateTime? _lastSampleAt;
  Timer? _saveDebounce;

  List<HistorySample> get samples => List<HistorySample>.unmodifiable(_samples);
  bool get loaded => _loaded;

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
    notifyListeners();
    _scheduleSave();
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
    super.dispose();
  }
}
