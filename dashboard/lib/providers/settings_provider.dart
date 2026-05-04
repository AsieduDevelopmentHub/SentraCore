import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kHost = 'engine_host';
  static const _kPort = 'engine_port';
  static const _kDesktopNotif = 'desktop_notifications';
  static const _kTheme = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  String _engineHost = '127.0.0.1';
  int _enginePort = 8740;
  bool _desktopNotifications = true;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  String get engineHost => _engineHost;
  int get enginePort => _enginePort;
  bool get desktopNotificationsEnabled => _desktopNotifications;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _engineHost = p.getString(_kHost) ?? '127.0.0.1';
    _enginePort = p.getInt(_kPort) ?? 8740;
    _desktopNotifications = p.getBool(_kDesktopNotif) ?? true;
    final t = p.getString(_kTheme);
    if (t == 'light') {
      _themeMode = ThemeMode.light;
    } else if (t == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHost, _engineHost);
    await p.setInt(_kPort, _enginePort);
    await p.setBool(_kDesktopNotif, _desktopNotifications);
    final tm = _themeMode == ThemeMode.light
        ? 'light'
        : _themeMode == ThemeMode.system
            ? 'system'
            : 'dark';
    await p.setString(_kTheme, tm);
  }

  void setEngineHost(String v) {
    _engineHost = v.trim();
    if (_engineHost.isEmpty) _engineHost = '127.0.0.1';
    notifyListeners();
  }

  void setEnginePort(int v) {
    _enginePort = v.clamp(1, 65535);
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
}
