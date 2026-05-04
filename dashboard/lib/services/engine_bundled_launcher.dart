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

  static Process? _ownedProcess;
  static bool _engineStartedByApp = false;

  static bool get engineStartedByApp => _engineStartedByApp;

  /// Path to the packaged engine exe, or null if not present (e.g. dev builds).
  static String? bundledEngineExecutablePath() {
    final dir = File(Platform.resolvedExecutable).parent;
    final name =
        Platform.isWindows ? 'SentraCoreEngine.exe' : 'SentraCoreEngine';
    final candidate = File('${dir.path}${Platform.pathSeparator}$name');
    return candidate.existsSync() ? candidate.path : null;
  }

  /// Discover a running engine; if not present, start bundled engine from the app
  /// executable directory and wait until [/api/v1/health] is ready.
  static Future<EngineBootstrapOutcome> ensureReady(
      {int? preferredPort,
      Duration timeout = const Duration(seconds: 25)}) async {
    _engineStartedByApp = false;

    var port = await EnginePortResolver.discoverPort(
      preferredPort: preferredPort,
      timeoutSeconds: timeout.inSeconds,
      scanStart: EngineService.defaultPort,
      scanEndExclusive: EngineService.defaultPort + 1,
    );
    if (port != null) {
      return EngineBootstrapOutcome(success: true, activePort: port);
    }

    final exe = bundledEngineExecutablePath();
    if (exe == null) {
      return const EngineBootstrapOutcome(
        success: false,
        message: 'Backend engine not found next to the app.',
        activePort: EngineService.defaultPort,
      );
    }

    // Start engine from app executable directory (single source of truth).
    try {
      _ownedProcess = await Process.start(
        exe,
        const <String>[],
        workingDirectory: File(exe).parent.path,
        // Keep a handle so we can stop it on app exit.
        mode: Platform.isWindows
            ? ProcessStartMode.detachedWithStdio
            : ProcessStartMode.normal,
      );
      _engineStartedByApp = true;
    } catch (e) {
      return EngineBootstrapOutcome(
        success: false,
        message: 'Could not start SentraCoreEngine: $e',
        activePort: EngineService.defaultPort,
      );
    }

    // Strict readiness gate: health must go green within timeout.
    port = await EnginePortResolver.discoverPort(
      preferredPort: preferredPort ?? EngineService.defaultPort,
      timeoutSeconds: timeout.inSeconds,
      scanStart: EngineService.defaultPort,
      scanEndExclusive: EngineService.defaultPort + 1,
    );
    if (port != null) {
      return EngineBootstrapOutcome(success: true, activePort: port);
    }

    return const EngineBootstrapOutcome(
      success: false,
      message: 'Backend did not become ready in time.',
      activePort: EngineService.defaultPort,
    );
  }

  /// Stop the engine only if it was started by this launcher.
  static Future<void> stopOwnedEngine() async {
    if (!_engineStartedByApp) return;
    final p = _ownedProcess;
    _ownedProcess = null;
    _engineStartedByApp = false;
    if (p == null) return;
    try {
      // Try graceful terminate first.
      p.kill();
      // Give it a moment.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (p.kill(ProcessSignal.sigkill)) {
        // best-effort
      }
    } catch (_) {
      // Best effort.
    }
  }
}
