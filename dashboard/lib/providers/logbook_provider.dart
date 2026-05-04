import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sentracore_dashboard/models/logbook_entry.dart';

class LogbookProvider extends ChangeNotifier {
  static const _kLogbookEntries = 'logbook_entries_v1';

  final List<LogbookEntry> _entries = [];
  bool _loaded = false;
  Timer? _saveDebounce;

  List<LogbookEntry> get entries {
    final copy = List<LogbookEntry>.from(_entries);
    copy.sort((a, b) => b.at.compareTo(a.at));
    return copy;
  }

  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLogbookEntries);
    if (raw == null || raw.trim().isEmpty) {
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _entries
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
                  (m) => LogbookEntry.fromJson(
                    Map<String, dynamic>.from(m),
                  ),
                ),
          );
      }
    } catch (_) {
      // Keep empty logbook on corrupt payload; user can rebuild over time.
    }
    _loaded = true;
    notifyListeners();
  }

  void add(LogbookEntry e) {
    _entries.add(e);
    notifyListeners();
    _scheduleSave();
  }

  void deleteById(String id) {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    _scheduleSave();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_saveNow());
    });
  }

  Future<void> _saveNow() async {
    final p = await SharedPreferences.getInstance();
    final payload = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await p.setString(_kLogbookEntries, payload);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    super.dispose();
  }
}
