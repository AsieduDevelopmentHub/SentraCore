import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local UI preferences + alert/safeguard tuning (synced to engine via REST).
class SettingsProvider extends ChangeNotifier {
  static const _kDesktopNotif = 'desktop_notifications';
  static const _kTheme = 'theme_mode';
  static const _kLastEnginePort = 'engine_last_http_port';
  static const _kAlertCpu = 'alert_cpu_percent';
  static const _kAlertMem = 'alert_memory_percent';
  static const _kAlertDisk = 'alert_disk_pressure';
  static const _kSafeguardOn = 'safeguard_enabled';
  static const _kSafeguardNames = 'safeguard_process_names';
  static const _kAnomalySensitivity = 'anomaly_sensitivity';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _desktopNotifications = true;

  double _alertCpuPercent = 85;
  double _alertMemoryPercent = 85;
  double _alertDiskPressure = 80;
  bool _safeguardEnabled = false;
  String _safeguardProcessNames = '';

  /// Engine + UI: lenient | normal | strict (anomaly label bands).
  String _anomalySensitivity = 'normal';
  int _lastEngineHttpPort = 8740;

  Timer? _autoSaveDebounce;
  static const Duration _autoSaveDebounceWindow = Duration(milliseconds: 350);

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get desktopNotificationsEnabled => _desktopNotifications;

  double get alertCpuPercent => _alertCpuPercent;
  double get alertMemoryPercent => _alertMemoryPercent;
  double get alertDiskPressure => _alertDiskPressure;
  bool get safeguardEnabled => _safeguardEnabled;
  String get safeguardProcessNames => _safeguardProcessNames;
  String get anomalySensitivity => _anomalySensitivity;
  int get lastEngineHttpPort => _lastEngineHttpPort;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _desktopNotifications = p.getBool(_kDesktopNotif) ?? true;
    final t = p.getString(_kTheme);
    if (t == 'light') {
      _themeMode = ThemeMode.light;
    } else if (t == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }
    _alertCpuPercent = p.getDouble(_kAlertCpu) ?? 85;
    _alertMemoryPercent = p.getDouble(_kAlertMem) ?? 85;
    _alertDiskPressure = p.getDouble(_kAlertDisk) ?? 80;
    _safeguardEnabled = p.getBool(_kSafeguardOn) ?? false;
    _safeguardProcessNames = p.getString(_kSafeguardNames) ?? '';
    _anomalySensitivity = p.getString(_kAnomalySensitivity) ?? 'normal';
    if (!_isValidAnomalySensitivity(_anomalySensitivity)) {
      _anomalySensitivity = 'normal';
    }
    _lastEngineHttpPort = p.getInt(_kLastEnginePort) ?? 8740;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDesktopNotif, _desktopNotifications);
    final tm = _themeMode == ThemeMode.light
        ? 'light'
        : _themeMode == ThemeMode.system
            ? 'system'
            : 'dark';
    await p.setString(_kTheme, tm);
    await p.setDouble(_kAlertCpu, _alertCpuPercent);
    await p.setDouble(_kAlertMem, _alertMemoryPercent);
    await p.setDouble(_kAlertDisk, _alertDiskPressure);
    await p.setBool(_kSafeguardOn, _safeguardEnabled);
    await p.setString(_kSafeguardNames, _safeguardProcessNames);
    await p.setString(_kAnomalySensitivity, _anomalySensitivity);
    await p.setInt(_kLastEnginePort, _lastEngineHttpPort);
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(_autoSaveDebounceWindow, () {
      unawaited(save());
    });
  }

  Future<void> setLastEngineHttpPort(int port) async {
    _lastEngineHttpPort = port.clamp(1, 65535);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastEnginePort, _lastEngineHttpPort);
    notifyListeners();
  }

  void setDesktopNotifications(bool v) {
    _desktopNotifications = v;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setThemeMode(ThemeMode m) {
    _themeMode = m;
    notifyListeners();
    _scheduleAutoSave();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setAlertCpuPercent(double v) {
    _alertCpuPercent = v.clamp(1, 100);
    notifyListeners();
    _scheduleAutoSave();
  }

  void setAlertMemoryPercent(double v) {
    _alertMemoryPercent = v.clamp(1, 100);
    notifyListeners();
    _scheduleAutoSave();
  }

  void setAlertDiskPressure(double v) {
    _alertDiskPressure = v.clamp(1, 100);
    notifyListeners();
    _scheduleAutoSave();
  }

  void setSafeguardEnabled(bool v) {
    _safeguardEnabled = v;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setSafeguardProcessNames(String v) {
    _safeguardProcessNames = v;
    notifyListeners();
    _scheduleAutoSave();
  }

  static bool _isValidAnomalySensitivity(String v) {
    return v == 'lenient' || v == 'normal' || v == 'strict';
  }

  void setAnomalySensitivity(String v) {
    final s = v.toLowerCase().trim();
    _anomalySensitivity = _isValidAnomalySensitivity(s) ? s : 'normal';
    notifyListeners();
    _scheduleAutoSave();
  }

  List<String> _parseSafeguardLines() {
    return _safeguardProcessNames
        .split(RegExp(r'[\r\n,;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Names to show as safeguard checkboxes: snapshot processes plus any saved names.
  List<String> safeguardPickList(Iterable<String> snapshotProcessNames) {
    final merged = {
      ...snapshotProcessNames,
      ..._parseSafeguardLines(),
    }.toList();
    merged.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    return merged;
  }

  bool safeguardHasName(String name) {
    final l = name.toLowerCase();
    return _parseSafeguardLines().any((x) => x.toLowerCase() == l);
  }

  void toggleSafeguardProcessName(String name, bool selected) {
    final lines = List<String>.from(_parseSafeguardLines());
    final l = name.toLowerCase();
    if (selected) {
      if (!lines.any((x) => x.toLowerCase() == l)) {
        lines.add(name);
      }
    } else {
      lines.removeWhere((x) => x.toLowerCase() == l);
    }
    _safeguardProcessNames = lines.join('\n');
    notifyListeners();
    _scheduleAutoSave();
  }

  void addSafeguardProcessNameLine(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    toggleSafeguardProcessName(t, true);
  }

  /// Apply JSON from [GET /api/v1/preferences] (does not persist to disk here).
  void applyFromEngine(Map<String, dynamic> json) {
    _alertCpuPercent = (json['alert_cpu_percent'] as num?)?.toDouble() ?? 85;
    _alertMemoryPercent =
        (json['alert_memory_percent'] as num?)?.toDouble() ?? 85;
    _alertDiskPressure =
        (json['alert_disk_pressure'] as num?)?.toDouble() ?? 80;
    _safeguardEnabled = json['safeguard_enabled'] as bool? ?? false;
    final names = json['safeguard_process_names'];
    if (names is List) {
      _safeguardProcessNames = names.map((e) => '$e').join('\n');
    } else {
      _safeguardProcessNames = '';
    }
    final sens =
        '${json['anomaly_sensitivity'] ?? 'normal'}'.toLowerCase().trim();
    _anomalySensitivity = _isValidAnomalySensitivity(sens) ? sens : 'normal';
    notifyListeners();
    _scheduleAutoSave();
  }

  Map<String, dynamic> toEngineJson() {
    final lines = _parseSafeguardLines();
    return {
      'alert_cpu_percent': _alertCpuPercent,
      'alert_memory_percent': _alertMemoryPercent,
      'alert_disk_pressure': _alertDiskPressure,
      'safeguard_enabled': _safeguardEnabled,
      'safeguard_process_names': lines,
      'anomaly_sensitivity': _anomalySensitivity,
    };
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = null;
    super.dispose();
  }
}
