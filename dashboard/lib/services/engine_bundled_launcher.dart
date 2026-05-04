import 'dart:io';

import 'package:sentracore_dashboard/services/engine_port_resolver.dart';
import 'package:sentracore_dashboard/services/engine_service.dart';

/// Outcome of trying to ensure the packaged engine is running (Windows install).
class EngineBootstrapOutcome {
  final bool success;
  final String? message;

  /// Port where [GET /api/v1/health] succeeded (or fallback when skipped).
  final int activePort;

  const EngineBootstrapOutcome({
    required this.success,
    this.message,
    this.activePort = EngineService.defaultPort,
  });
}

/// Starts [SentraCoreEngine.exe] next to the dashboard when installed via Inno Setup,
/// then waits until the HTTP API is up on whatever port the engine chose (8740+).
class EngineBundledLauncher {
  EngineBundledLauncher._();

  /// Path to the packaged engine exe, or null if not present (e.g. dev builds).
  static String? bundledEngineExecutablePath() {
    if (!Platform.isWindows) return null;
    final dir = File(Platform.resolvedExecutable).parent;
    final candidate =
        File('${dir.path}${Platform.pathSeparator}SentraCoreEngine.exe');
    return candidate.existsSync() ? candidate.path : null;
  }

  /// Discover a running engine, optionally starting the Windows bundled exe first.
  static Future<EngineBootstrapOutcome> ensureReady(
      {int? preferredPort}) async {
    if (!Platform.isWindows) {
      final p =
          await EnginePortResolver.discoverPort(preferredPort: preferredPort);
      return EngineBootstrapOutcome(
        success: true,
        activePort: p ?? EngineService.defaultPort,
      );
    }

    var port =
        await EnginePortResolver.discoverPort(preferredPort: preferredPort);
    if (port != null) {
      return EngineBootstrapOutcome(success: true, activePort: port);
    }

    final exe = bundledEngineExecutablePath();
    if (exe != null) {
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
          activePort: EngineService.defaultPort,
        );
      }

      port =
          await EnginePortResolver.discoverPort(preferredPort: preferredPort);
      if (port != null) {
        return EngineBootstrapOutcome(success: true, activePort: port);
      }

      // Cold start can exceed one poll window; retry discovery before failing.
      await Future<void>.delayed(const Duration(seconds: 2));
      port =
          await EnginePortResolver.discoverPort(preferredPort: preferredPort);
      if (port != null) {
        return EngineBootstrapOutcome(success: true, activePort: port);
      }

      return EngineBootstrapOutcome(
        success: false,
        message:
            'Engine did not become ready. It may have crashed, or ports are blocked.',
        activePort: EngineService.defaultPort,
      );
    }

    // Windows dev: no bundled exe — try default port only (same as legacy skip).
    return EngineBootstrapOutcome(
        success: true, activePort: EngineService.defaultPort);
  }
}
