import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Outcome of trying to ensure the packaged engine is running (Windows install).
class EngineBootstrapOutcome {
  final bool success;
  final String? message;

  const EngineBootstrapOutcome({required this.success, this.message});
}

/// Starts [SentraCoreEngine.exe] next to the dashboard when installed via Inno Setup,
/// then waits until the HTTP API reports the engine is initialized.
///
/// Skipped when:
/// - Not Windows
/// - [host] is not a local loopback address (remote engine)
/// - No `SentraCoreEngine.exe` beside this process (typical `flutter run` dev layout)
class EngineBundledLauncher {
  EngineBundledLauncher._();

  static bool _isLocalHost(String host) {
    final h = host.toLowerCase().trim();
    return h == '127.0.0.1' || h == 'localhost' || h == '::1';
  }

  /// Path to the packaged engine exe, or null if not present (e.g. dev builds).
  static String? bundledEngineExecutablePath() {
    if (!Platform.isWindows) return null;
    final dir = File(Platform.resolvedExecutable).parent;
    final candidate =
        File('${dir.path}${Platform.pathSeparator}SentraCoreEngine.exe');
    return candidate.existsSync() ? candidate.path : null;
  }

  static String _healthUrl(String host, int port) {
    final h = host.trim();
    final authority = h == '::1' ? '[::1]:$port' : '$h:$port';
    return 'http://$authority/api/v1/health';
  }

  static Future<bool> _engineHealthy(String host, int port) async {
    try {
      final r = await http
          .get(Uri.parse(_healthUrl(host, port)))
          .timeout(const Duration(milliseconds: 900));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return j['engine'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the local engine process is up and responding, starting it if needed.
  static Future<EngineBootstrapOutcome> ensureReady({
    required String host,
    required int port,
  }) async {
    if (!_isLocalHost(host)) {
      return const EngineBootstrapOutcome(success: true);
    }
    if (!Platform.isWindows) {
      return const EngineBootstrapOutcome(success: true);
    }

    if (await _engineHealthy(host, port)) {
      return const EngineBootstrapOutcome(success: true);
    }

    final exe = bundledEngineExecutablePath();
    if (exe == null) {
      return const EngineBootstrapOutcome(success: true);
    }

    try {
      await Process.start(
        exe,
        const <String>[],
        workingDirectory: File(exe).parent.path,
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      return EngineBootstrapOutcome(
        success: false,
        message: 'Could not start SentraCoreEngine.exe: $e',
      );
    }

    const step = Duration(milliseconds: 450);
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      if (await _engineHealthy(host, port)) {
        return const EngineBootstrapOutcome(success: true);
      }
      await Future<void>.delayed(step);
    }

    return EngineBootstrapOutcome(
      success: false,
      message: 'Engine did not become ready on port $port. '
          'It may have crashed, or another program is using that port.',
    );
  }
}
