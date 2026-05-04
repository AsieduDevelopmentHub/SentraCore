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

  ThemeMode _themeMode = ThemeMode.dark;
  bool _desktopNotifications = true;

  double _alertCpuPercent = 85;
  double _alertMemoryPercent = 85;
  double _alertDiskPressure = 80;
  bool _safeguardEnabled = false;
  String _safeguardProcessNames = '';
  int _lastEngineHttpPort = 8740;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get desktopNotificationsEnabled => _desktopNotifications;

  double get alertCpuPercent => _alertCpuPercent;
  double get alertMemoryPercent => _alertMemoryPercent;
  double get alertDiskPressure => _alertDiskPressure;
  bool get safeguardEnabled => _safeguardEnabled;
  String get safeguardProcessNames => _safeguardProcessNames;
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
    await p.setInt(_kLastEnginePort, _lastEngineHttpPort);
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
  }

  void setThemeMode(ThemeMode m) {
    _themeMode = m;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setAlertCpuPercent(double v) {
    _alertCpuPercent = v.clamp(1, 100);
    notifyListeners();
  }

  void setAlertMemoryPercent(double v) {
    _alertMemoryPercent = v.clamp(1, 100);
    notifyListeners();
  }

  void setAlertDiskPressure(double v) {
    _alertDiskPressure = v.clamp(1, 100);
    notifyListeners();
  }

  void setSafeguardEnabled(bool v) {
    _safeguardEnabled = v;
    notifyListeners();
  }

  void setSafeguardProcessNames(String v) {
    _safeguardProcessNames = v;
    notifyListeners();
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
    notifyListeners();
  }

  Map<String, dynamic> toEngineJson() {
    final lines = _safeguardProcessNames
        .split(RegExp(r'[\r\n,;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return {
      'alert_cpu_percent': _alertCpuPercent,
      'alert_memory_percent': _alertMemoryPercent,
      'alert_disk_pressure': _alertDiskPressure,
      'safeguard_enabled': _safeguardEnabled,
      'safeguard_process_names': lines,
    };
  }
}
