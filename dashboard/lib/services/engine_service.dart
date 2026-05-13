import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sentracore_dashboard/models/system_state.dart';

/// Service for communicating with the SentraCore Python engine.
///
/// Handles both REST API calls and WebSocket real-time streaming.
class EngineService {
  final String host;
  final int port;

  late final String _baseUrl;
  late final String _wsUrl;

  WebSocketChannel? _liveChannel;
  WebSocketChannel? _alertChannel;

  EngineService({required this.host, required this.port}) {
    _baseUrl = 'http://$host:$port';
    _wsUrl = 'ws://$host:$port';
  }

  // ── REST API ──

  Future<Map<String, dynamic>?> getHealth() async {
    return _get('/api/v1/health');
  }

  Future<SystemState?> getStatus() async {
    final data = await _get('/api/v1/status');
    if (data != null) {
      return SystemState.fromJson(data);
    }
    return null;
  }

  Future<List<ProcessImpact>> getProcesses({int limit = 50}) async {
    final data = await _get('/api/v1/processes?limit=$limit');
    if (data != null && data['processes'] != null) {
      return (data['processes'] as List)
          .map((p) => ProcessImpact.fromJson(p))
          .toList();
    }
    return [];
  }

  Future<List<SystemEvent>> getEvents() async {
    final data = await _get('/api/v1/events');
    if (data != null && data['events'] != null) {
      return (data['events'] as List)
          .map((e) => SystemEvent.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> postProcessAction(
      int pid, String action) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/processes/$pid/action');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': action}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getBaseline() async {
    return _get('/api/v1/baseline');
  }

  Future<Map<String, dynamic>?> getUserPreferences() async {
    return _get('/api/v1/preferences');
  }

  Future<Map<String, dynamic>?> putUserPreferences(
      Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/preferences');
      final response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // ── History & storage ──

  /// Fetch persisted history samples. Returns an empty list on any failure;
  /// callers should fall back to the local offline cache if needed.
  ///
  /// [granularitySec] sets the minimum spacing between returned samples so
  /// long ranges can render without overloading the chart.
  Future<List<Map<String, dynamic>>> getHistory({
    DateTime? from,
    DateTime? to,
    double? granularitySec,
    int? limit,
  }) async {
    final qs = <String, String>{};
    if (from != null) {
      qs['from'] = (from.millisecondsSinceEpoch / 1000).toStringAsFixed(3);
    }
    if (to != null) {
      qs['to'] = (to.millisecondsSinceEpoch / 1000).toStringAsFixed(3);
    }
    if (granularitySec != null) {
      qs['granularity'] = granularitySec.toStringAsFixed(2);
    }
    if (limit != null) {
      qs['limit'] = limit.toString();
    }
    final uri = Uri.parse('$_baseUrl/api/v1/history').replace(
      queryParameters: qs.isEmpty ? null : qs,
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const [];
      final samples = decoded['samples'];
      if (samples is! List) return const [];
      return samples
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> deleteHistory() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/history');
      final response =
          await http.delete(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getStorageInfo() async {
    return _get('/api/v1/storage/info');
  }

  Future<Map<String, dynamic>?> clearCache() async {
    return _post('/api/v1/storage/cache/clear');
  }

  Future<Map<String, dynamic>?> resetBaseline() async {
    return _post('/api/v1/state/reset/baseline');
  }

  // ── Cleanup scan + large file finder ──

  Future<Map<String, dynamic>?> getCleanupCategories() async {
    return _get('/api/v1/cleanup/categories');
  }

  /// Run a cleanup scan; pass [categoryIds] to limit which buckets are walked.
  Future<Map<String, dynamic>?> runCleanupScan({
    List<String>? categoryIds,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/cleanup/scan');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (categoryIds != null) 'category_ids': categoryIds,
            }),
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Apply a previously recorded scan. [mode] is "recycle" or "permanent".
  Future<Map<String, dynamic>?> applyCleanup({
    required String scanId,
    required List<String> categoryIds,
    String mode = 'recycle',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/cleanup/apply');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'scan_id': scanId,
              'category_ids': categoryIds,
              'mode': mode,
            }),
          )
          .timeout(const Duration(seconds: 180));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Hardware health probe; engine can take 10–20s — uses an extended timeout.
  Future<Map<String, dynamic>?> getHardwareHealth(
      {bool refresh = false}) async {
    final qs = refresh ? '?refresh=true' : '';
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/hardware/health$qs');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Run one hardware probe (cpu / memory / disk); same long timeout as full health.
  Future<Map<String, dynamic>?> getHardwareTest(String target) async {
    final t = Uri.encodeQueryComponent(target);
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/hardware/test?target=$t');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200 || response.statusCode == 422) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> findLargeFiles({
    required String path,
    double minMb = 100.0,
    int limit = 200,
  }) async {
    final qs = {
      'path': path,
      'min_mb': minMb.toStringAsFixed(2),
      'limit': limit.toString(),
    };
    final uri = Uri.parse('$_baseUrl/api/v1/storage/large')
        .replace(queryParameters: qs);
    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // ── WebSocket Live Stream ──

  Stream<SystemState> connectLive() {
    _liveChannel?.sink.close();
    _liveChannel = WebSocketChannel.connect(Uri.parse('$_wsUrl/ws/live'));

    return _liveChannel!.stream.map((message) {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      return SystemState.fromJson(data);
    });
  }

  // ── WebSocket Alert Stream ──

  Stream<Map<String, dynamic>> connectAlerts() {
    _alertChannel?.sink.close();
    _alertChannel = WebSocketChannel.connect(Uri.parse('$_wsUrl/ws/alerts'));

    return _alertChannel!.stream.map((message) {
      return jsonDecode(message as String) as Map<String, dynamic>;
    });
  }

  // ── Cleanup ──

  void dispose() {
    _liveChannel?.sink.close();
    _alertChannel?.sink.close();
  }

  // ── Internal ──

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Connection error — engine might not be running
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(String path) async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }
}
