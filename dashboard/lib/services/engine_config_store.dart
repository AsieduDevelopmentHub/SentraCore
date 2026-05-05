import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Single source of truth for engine host/port and lifecycle state.
///
/// This file must be writable by the current user. On Windows/macOS installed
/// apps often live under protected directories (e.g. Program Files), so we store
/// config under per-user app data and pass its location to the engine via
/// SENTRACORE_ENGINE_CONFIG.
class EngineConfigStore {
  EngineConfigStore._();

  static const String fileName = 'engine-config.json';

  /// Absolute path to the writable engine-config.json for this user.
  static String engineConfigPath() => _configFile().path;

  static Directory _configDir() {
    if (Platform.isWindows) {
      final base = Platform.environment['LOCALAPPDATA'];
      if (base != null && base.trim().isNotEmpty) {
        return Directory('${base.trim()}${Platform.pathSeparator}SentraCore');
      }
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        return Directory(
            '${home.trim()}${Platform.pathSeparator}Library${Platform.pathSeparator}Application Support${Platform.pathSeparator}SentraCore');
      }
    }
    // Linux / fallback
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.trim().isNotEmpty) {
      return Directory('${xdg.trim()}${Platform.pathSeparator}sentracore');
    }
    final home = Platform.environment['HOME'] ?? '';
    if (home.trim().isNotEmpty) {
      return Directory(
          '${home.trim()}${Platform.pathSeparator}.config${Platform.pathSeparator}sentracore');
    }
    // Last resort: alongside executable (may be read-only; caller handles errors).
    return File(Platform.resolvedExecutable).parent;
  }

  static File _configFile() {
    final dir = _configDir();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  static File _legacyConfigFileNextToExe() {
    final dir = File(Platform.resolvedExecutable).parent;
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  static Future<void> _migrateLegacyIfPresent() async {
    final legacy = _legacyConfigFileNextToExe();
    final target = _configFile();
    try {
      if (await target.exists()) return;
      if (!await legacy.exists()) return;
      await target.parent.create(recursive: true);
      await legacy.copy(target.path);
    } catch (_) {
      // Best-effort migration only.
    }
  }

  static String connectHostForUi() => '127.0.0.1';

  static String bindHostForOs() {
    // Linux AppImage: bind all interfaces; others local-only.
    return Platform.isLinux ? '0.0.0.0' : '127.0.0.1';
  }

  static Future<EngineConfig> readOrCreate() async {
    await _migrateLegacyIfPresent();
    final f = _configFile();
    if (!await f.exists()) {
      return _restoreFromBundledTemplate();
    }
    final cfg = await read();
    if (cfg != null) return cfg;
    return _restoreFromBundledTemplate();
  }

  static Future<EngineConfig?> read() async {
    await _migrateLegacyIfPresent();
    final f = _configFile();
    try {
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return EngineConfig.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Sync read for early [EngineService] wiring (must exist after startup gate).
  static EngineConfig? tryReadSync() {
    final f = _configFile();
    try {
      if (!f.existsSync()) return null;
      final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return EngineConfig.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeAtomic(EngineConfig cfg) async {
    await _migrateLegacyIfPresent();
    final f = _configFile();
    final dir = f.parent;
    await dir.create(recursive: true);
    final tmp = File(
        '${dir.path}${Platform.pathSeparator}$fileName.${DateTime.now().microsecondsSinceEpoch}.tmp');
    final payload = const JsonEncoder.withIndent('  ').convert(cfg.toJson());
    await tmp.writeAsString(payload, flush: true);
    try {
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // Best-effort.
    }
    await tmp.rename(f.path);
  }

  static Future<EngineConfig> _restoreFromBundledTemplate() async {
    // No hardcoded ports in code: bootstrap from the bundled config template.
    final raw = await rootBundle.loadString('assets/engine-config.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final base = EngineConfig.fromJson(j);
    final normalized = base.copyWith(
      host: connectHostForUi(),
      bindHost: bindHostForOs(),
      status: EngineStatus.starting,
    );
    await writeAtomic(normalized);
    return normalized;
  }
}

enum EngineStatus {
  stopped,
  starting,
  healthChecking,
  running,
  restarting,
  failed,
}

class EngineConfig {
  final String host; // UI connect host
  final int port;
  final EngineStatus status;
  final int pid;
  final String lastError;

  /// Optional bind target for the engine (can differ from [host]).
  final String? bindHost;

  const EngineConfig({
    required this.host,
    required this.port,
    required this.status,
    this.pid = 0,
    this.lastError = '',
    this.bindHost,
  });

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'bind_host': bindHost ?? '',
        'status': _statusToString(status),
        'pid': pid,
        'last_error': lastError,
      };

  static EngineConfig fromJson(Map<String, dynamic> j) {
    final host = (j['host'] as String?)?.trim();
    final port = (j['port'] as num?)?.toInt();
    final status = (j['status'] as String?)?.trim();
    if (host == null || host.isEmpty || port == null) {
      throw const FormatException('engine-config.json missing host/port');
    }
    final bh = (j['bind_host'] as String?)?.trim();
    return EngineConfig(
      host: host,
      port: port,
      status: _statusFromString(status),
      pid: (j['pid'] as num?)?.toInt() ?? 0,
      lastError: (j['last_error'] as String?) ?? '',
      bindHost: (bh != null && bh.isNotEmpty) ? bh : null,
    );
  }

  EngineConfig copyWith({
    String? host,
    int? port,
    EngineStatus? status,
    int? pid,
    String? lastError,
    String? bindHost,
  }) {
    return EngineConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      status: status ?? this.status,
      pid: pid ?? this.pid,
      lastError: lastError ?? this.lastError,
      bindHost: bindHost ?? this.bindHost,
    );
  }
}

String _statusToString(EngineStatus s) {
  switch (s) {
    case EngineStatus.stopped:
      return 'stopped';
    case EngineStatus.starting:
      return 'starting';
    case EngineStatus.healthChecking:
      return 'health_checking';
    case EngineStatus.running:
      return 'running';
    case EngineStatus.restarting:
      return 'restarting';
    case EngineStatus.failed:
      return 'failed';
  }
}

EngineStatus _statusFromString(String? s) {
  switch (s) {
    case 'stopped':
      return EngineStatus.stopped;
    case 'starting':
      return EngineStatus.starting;
    case 'health_checking':
      return EngineStatus.healthChecking;
    case 'running':
      return EngineStatus.running;
    case 'restarting':
      return EngineStatus.restarting;
    case 'failed':
      return EngineStatus.failed;
  }
  return EngineStatus.stopped;
}
