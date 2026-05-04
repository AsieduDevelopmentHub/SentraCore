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

  EngineService({this.host = '127.0.0.1', this.port = 8740}) {
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

  Future<List<ProcessImpact>> getProcesses() async {
    final data = await _get('/api/v1/processes');
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
}
