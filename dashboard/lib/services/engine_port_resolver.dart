import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sentracore_dashboard/services/engine_service.dart';

/// Discovers which TCP port the local engine is listening on (8740+ if busy).
class EnginePortResolver {
  EnginePortResolver._();

  static String? _runtimeFilePath() {
    if (Platform.isWindows) {
      final la = Platform.environment['LOCALAPPDATA'];
      if (la == null || la.isEmpty) return null;
      return '$la${Platform.pathSeparator}SentraCore${Platform.pathSeparator}datastore${Platform.pathSeparator}engine_runtime.json';
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/.local/share/SentraCore/datastore/engine_runtime.json';
    }
    return null;
  }

  static int? _readPortFromRuntimeFile() {
    final path = _runtimeFilePath();
    if (path == null) return null;
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return (j['http_port'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// If [engine_runtime.json] points at [port] but nothing healthy listens there,
  /// remove the file so discovery does not keep preferring a dead process (e.g.
  /// after taskkill / crash where the engine could not clear the file).
  static Future<void> clearStaleRuntimeFileIfPortDead(int port) async {
    final path = _runtimeFilePath();
    if (path == null) return;
    try {
      final f = File(path);
      if (!f.existsSync()) return;
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final recorded = (j['http_port'] as num?)?.toInt();
      if (recorded != port) return;
      if (await engineHealthy(EngineService.defaultHost, port)) return;
      await f.delete();
    } catch (_) {}
  }

  /// True when [GET /api/v1/health] reports the orchestrator is registered.
  static Future<bool> engineHealthy(String host, int port) async {
    try {
      final uri = Uri.parse('http://$host:$port/api/v1/health');
      final r = await http.get(uri).timeout(const Duration(milliseconds: 900));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return j['engine'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Waits until the engine responds on some port (runtime file, cache, or scan).
  ///
  /// [scanEndExclusive] caps a linear fallback scan; high ports are reached via
  /// `engine_runtime.json` written by the engine after bind.
  static Future<int?> discoverPort({
    int? preferredPort,
    int timeoutSeconds = 45,
    int scanStart = EngineService.defaultPort,
    int scanEndExclusive = 8900,
  }) async {
    const host = EngineService.defaultHost;
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));

    while (DateTime.now().isBefore(deadline)) {
      if (preferredPort != null) {
        if (await engineHealthy(host, preferredPort)) {
          return preferredPort;
        }
      }

      final fromFile = _readPortFromRuntimeFile();
      if (fromFile != null) {
        if (await engineHealthy(host, fromFile)) {
          return fromFile;
        }
        await clearStaleRuntimeFileIfPortDead(fromFile);
      }

      for (var p = scanStart; p < scanEndExclusive; p++) {
        if (await engineHealthy(host, p)) {
          return p;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }
}
