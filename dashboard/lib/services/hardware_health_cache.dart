import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last successful hardware health payload so the Hardware
/// screen can render immediately while the engine probe runs (10–20s).
class HardwareHealthCache {
  static const _key = 'hardware_health_last_ok_v1';

  static Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      if (m['ok'] == true) return m;
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Store only successful engine responses (`ok: true`).
  /// Returns the payload including `cached_at_ms` for immediate UI use.
  static Future<Map<String, dynamic>?> write(
      Map<String, dynamic> payload) async {
    if (payload['ok'] != true) return null;
    final prefs = await SharedPreferences.getInstance();
    final enriched = Map<String, dynamic>.from(payload)
      ..['cached_at_ms'] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_key, jsonEncode(enriched));
    return enriched;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
