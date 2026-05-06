import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sentracore_dashboard/services/engine_config_store.dart';

/// Outcome of the deterministic engine lifecycle FSM.
class EngineBootstrapOutcome {
  final bool success;
  final String? message;
  final String activeHost;
  final int activePort;

  const EngineBootstrapOutcome({
    required this.success,
    this.message,
    required this.activeHost,
    required this.activePort,
  });
}

/// Deterministic engine lifecycle: single serial gate, config-only contract,
/// bounded health wait, max 3 restart cycles per attempt. Disk [failed] is cleared
/// only when [ensureReady] is called with [userRetry] true (dashboard does this on
/// cold start / reconnect when the config file still says failed).
class EngineBundledLauncher {
  EngineBundledLauncher._();

  static Process? _ownedProcess;
  static bool _engineStartedByApp = false;
  static bool _busy = false;

  static const Duration _healthWindow = Duration(seconds: 45);
  static const Duration _healthTick = Duration(milliseconds: 500);
  static const int _maxRestartCycles = 3;

  static bool get engineStartedByApp => _engineStartedByApp;

  static String? bundledEngineExecutablePath() {
    final dir = File(Platform.resolvedExecutable).parent;
    final name =
        Platform.isWindows ? 'SentraCoreEngine.exe' : 'SentraCoreEngine';
    final candidate = File('${dir.path}${Platform.pathSeparator}$name');
    return candidate.existsSync() ? candidate.path : null;
  }

  static Future<EngineBootstrapOutcome> ensureReadyUserRetry() =>
      ensureReady(userRetry: true);

  static Future<EngineBootstrapOutcome> ensureReady(
      {bool userRetry = false}) async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _busy = true;
    try {
      return await _ensureReadyImpl(
        userRetry: userRetry,
        forceRestart: false,
      );
    } finally {
      _busy = false;
    }
  }

  /// Watchdog path: only if this app started the engine.
  static Future<void> recoverOwnedAfterStall() async {
    if (!_engineStartedByApp) return;
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _busy = true;
    try {
      await stopOwnedEngine();
      await _ensureReadyImpl(
        userRetry: false,
        forceRestart: true,
      );
    } finally {
      _busy = false;
    }
  }

  static Future<EngineBootstrapOutcome> _ensureReadyImpl({
    required bool userRetry,
    required bool forceRestart,
  }) async {
    var cfg = await EngineConfigStore.readOrCreate();

    // Disk can say failed/starting while the engine is already up (external start,
    // installer, or a different launch path). If HTTP health succeeds, align disk and
    // connect — do not spawn a second engine. Stall recovery uses [forceRestart] and
    // skips this path.
    final httpHealthy =
        !forceRestart && await _strictHealth(cfg.host, cfg.port);
    if (httpHealthy) {
      final dirty = cfg.status != EngineStatus.running ||
          cfg.lastError.isNotEmpty;
      if (dirty) {
        cfg = cfg.copyWith(
          status: EngineStatus.running,
          lastError: '',
          pid: cfg.pid != 0 ? cfg.pid : 0,
        );
        await EngineConfigStore.writeAtomic(cfg);
      }
      if (!_engineStartedByApp) {
        _ownedProcess = null;
      }
      return EngineBootstrapOutcome(
        success: true,
        activeHost: cfg.host,
        activePort: cfg.port,
      );
    }

    // Disk still says "running" (e.g. Task Manager kill — Python never rewrote the
    // file). HTTP is down; clear stale state so we skip the long "wait for existing"
    // window on a dead PID.
    if (!forceRestart && !httpHealthy && cfg.status == EngineStatus.running) {
      cfg = cfg.copyWith(
        status: EngineStatus.stopped,
        lastError: '',
        pid: 0,
      );
      await EngineConfigStore.writeAtomic(cfg);
    }

    if (cfg.status == EngineStatus.failed && !userRetry) {
      return EngineBootstrapOutcome(
        success: false,
        message: cfg.lastError.isEmpty ? 'Engine failed.' : cfg.lastError,
        activeHost: cfg.host,
        activePort: cfg.port,
      );
    }

    if (userRetry && cfg.status == EngineStatus.failed) {
      cfg = cfg.copyWith(
        status: EngineStatus.starting,
        lastError: '',
        pid: 0,
      );
      await EngineConfigStore.writeAtomic(cfg);
    }

    if (!forceRestart) {
      // Wait for an in-flight or already-up engine on disk. Do not require pid != 0:
      // reconciled / external engines may show running with pid 0 until the next
      // writer refreshes; HTTP health is the real signal.
      final shouldWaitForExisting = cfg.status != EngineStatus.stopped &&
          cfg.status != EngineStatus.failed &&
          (cfg.pid != 0 ||
              cfg.status == EngineStatus.starting ||
              cfg.status == EngineStatus.healthChecking ||
              cfg.status == EngineStatus.running ||
              cfg.status == EngineStatus.restarting);
      final diskRunning = shouldWaitForExisting
          ? await _waitRunningOnDiskWithin(cfg.host, _healthWindow)
          : null;
      if (diskRunning != null) {
        _engineStartedByApp =
            _ownedProcess != null && diskRunning.pid == _ownedProcess!.pid;
        if (!_engineStartedByApp) {
          _ownedProcess = null;
        }
        return EngineBootstrapOutcome(
          success: true,
          activeHost: diskRunning.host,
          activePort: diskRunning.port,
        );
      }
    }

    final exe = bundledEngineExecutablePath();
    if (exe == null) {
      cfg = cfg.copyWith(
        status: EngineStatus.failed,
        lastError: 'Engine executable not found next to the app.',
        pid: 0,
      );
      await EngineConfigStore.writeAtomic(cfg);
      return EngineBootstrapOutcome(
        success: false,
        message: cfg.lastError,
        activeHost: cfg.host,
        activePort: cfg.port,
      );
    }

    for (var cycle = 0; cycle < _maxRestartCycles; cycle++) {
      await stopOwnedEngine();

      cfg = await EngineConfigStore.readOrCreate();
      final bindHost = cfg.bindHost ?? EngineConfigStore.bindHostForOs();
      final startPort = cfg.port;
      final newPort = await _findFirstFreeTcpPort(bindHost, startPort);

      final nextStatus =
          cycle == 0 ? EngineStatus.starting : EngineStatus.restarting;
      cfg = cfg.copyWith(
        port: newPort,
        status: nextStatus,
        bindHost: bindHost,
        lastError: '',
        pid: 0,
      );
      await EngineConfigStore.writeAtomic(cfg);

      final started = await _startOwnedEngine(exe);
      if (!started || _ownedProcess == null) {
        cfg = cfg.copyWith(
          status: EngineStatus.failed,
          lastError: 'Could not start SentraCoreEngine (engine).',
          pid: 0,
        );
        await EngineConfigStore.writeAtomic(cfg);
        return EngineBootstrapOutcome(
          success: false,
          message: cfg.lastError,
          activeHost: cfg.host,
          activePort: cfg.port,
        );
      }

      final childPid = _ownedProcess!.pid;
      cfg = cfg.copyWith(
        status: EngineStatus.healthChecking,
        pid: childPid,
        lastError: '',
      );
      await EngineConfigStore.writeAtomic(cfg);

      final runningCfg = await _waitRunningOnDiskWithin(cfg.host, _healthWindow);
      if (runningCfg != null &&
          runningCfg.status == EngineStatus.running &&
          await _strictHealth(runningCfg.host, runningCfg.port)) {
        // On Windows the engine may be a child of the started image; Python writes
        // os.getpid() to disk while [Process.pid] from Dart is a wrapper PID. Treat
        // HTTP health + disk "running" as success — do not require pid equality or we
        // time out, call [stopOwnedEngine], and kill the real listener in a loop.
        if (runningCfg.pid != 0 && runningCfg.pid != childPid) {
          _ownedProcess = null;
          _engineStartedByApp = false;
        }
        return EngineBootstrapOutcome(
          success: true,
          activeHost: runningCfg.host,
          activePort: runningCfg.port,
        );
      }

      await stopOwnedEngine();
      cfg = (await EngineConfigStore.readOrCreate()).copyWith(
        status: EngineStatus.restarting,
        lastError: 'Health check did not reach RUNNING in time.',
        pid: 0,
      );
      await EngineConfigStore.writeAtomic(cfg);
    }

    cfg = (await EngineConfigStore.readOrCreate()).copyWith(
      status: EngineStatus.failed,
      lastError: 'Exceeded maximum restart attempts.',
      pid: 0,
    );
    await EngineConfigStore.writeAtomic(cfg);
    return EngineBootstrapOutcome(
      success: false,
      message: cfg.lastError,
      activeHost: cfg.host,
      activePort: cfg.port,
    );
  }

  static Future<void> stopOwnedEngine() async {
    if (!_engineStartedByApp) return;
    final p = _ownedProcess;
    _ownedProcess = null;
    _engineStartedByApp = false;
    if (p == null) return;
    if (Platform.isWindows) {
      try {
        await Process.run(
          'taskkill',
          <String>['/PID', '${p.pid}', '/T', '/F'],
          runInShell: true,
        );
      } catch (_) {}
    }
    try {
      p.kill();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      p.kill(ProcessSignal.sigkill);
    } catch (_) {}
    try {
      final cur = await EngineConfigStore.read();
      if (cur != null) {
        await EngineConfigStore.writeAtomic(
          cur.copyWith(
            status: EngineStatus.stopped,
            pid: 0,
          ),
        );
      }
    } catch (_) {}
  }

  /// Ready when disk says [EngineStatus.running] and HTTP health passes on [disk.port].
  /// Do not require [EngineConfig.pid] to match [Process.start]'s pid: on Windows the
  /// listening process may be a child; the engine rewrites JSON with [os.getpid].
  static Future<EngineConfig?> _waitRunningOnDiskWithin(
    String connectHost,
    Duration window,
  ) async {
    final deadline = DateTime.now().add(window);
    while (DateTime.now().isBefore(deadline)) {
      final disk = await EngineConfigStore.read();
      if (disk != null && disk.status == EngineStatus.failed) {
        return null;
      }
      if (disk != null &&
          disk.status == EngineStatus.running &&
          await _strictHealth(connectHost, disk.port)) {
        return disk;
      }
      await Future<void>.delayed(_healthTick);
    }
    return null;
  }

  static Future<bool> _strictHealth(String host, int port) async {
    try {
      final uri = Uri.parse('http://$host:$port/api/v1/health');
      final r = await http.get(uri).timeout(const Duration(seconds: 2));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body);
      if (j is! Map<String, dynamic>) return false;
      return j['engine'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<int> _findFirstFreeTcpPort(
      String bindHost, int startPort) async {
    final addr = bindHost == '0.0.0.0'
        ? InternetAddress.anyIPv4
        : InternetAddress(bindHost);
    for (var p = startPort; p <= 65535; p++) {
      try {
        final s = await ServerSocket.bind(addr, p);
        await s.close();
        return p;
      } catch (_) {}
    }
    throw const SocketException('No free TCP port found.');
  }

  static Future<bool> _startOwnedEngine(String exe) async {
    try {
      _ownedProcess = await Process.start(
        exe,
        const <String>[],
        workingDirectory: File(exe).parent.path,
        mode: Platform.isWindows
            ? ProcessStartMode.detachedWithStdio
            : ProcessStartMode.normal,
        environment: {
          ...Platform.environment,
          'SENTRACORE_ENGINE_CONFIG': _engineConfigPath(),
        },
      );
      _engineStartedByApp = true;
      return true;
    } catch (e, st) {
      developer.log(
        'Engine start failed',
        name: 'EngineBundledLauncher',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  static String _engineConfigPath() {
    // Must be writable (installed apps may live under Program Files).
    // EngineConfigStore owns the authoritative location.
    return EngineConfigStore.engineConfigPath();
  }
}
