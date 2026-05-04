import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/providers/settings_provider.dart';
import 'package:sentracore_dashboard/services/desktop_notification_service.dart';
import 'package:sentracore_dashboard/services/engine_bundled_launcher.dart';
import 'package:sentracore_dashboard/services/engine_service.dart';

/// Central state management for the SentraCore dashboard.
///
/// Connects to the Python engine via WebSocket, maintains a history
/// of system states for charting, and exposes reactive state to the UI.
class EngineProvider extends ChangeNotifier {
  EngineProvider({
    required SettingsProvider settings,
    required DesktopNotificationService notifications,
  })  : _settings = settings,
        _notifications = notifications {
    _service = EngineService(port: settings.lastEngineHttpPort);
  }

  final SettingsProvider _settings;
  final DesktopNotificationService _notifications;
  late EngineService _service;

  // ── Connection State ──
  bool _connected = false;
  bool get connected => _connected;

  String _connectionError = '';
  String get connectionError => _connectionError;

  // ── Current State ──
  SystemState? _currentState;
  SystemState? get currentState => _currentState;

  StressResult? get stress => _currentState?.stress;
  NormalizedData? get normalized => _currentState?.normalized;
  PredictionResult? get prediction => _currentState?.prediction;
  StabilityIndex? get stability => _currentState?.stability;
  EngineInfo? get engineInfo => _currentState?.engine;

  /// Monotonic deadline for alert cooldown UI (smooth countdown between engine ticks).
  DateTime? _cooldownDeadline;

  /// Seconds remaining in alert cooldown (0 if none), updated every second while active.
  int get displayCooldownRemainingSec {
    if (_cooldownDeadline == null) return 0;
    final s = _cooldownDeadline!.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  // ── History for Charts (last 60 data points = ~2 minutes) ──
  static const int _historySize = 60;

  final Queue<double> _cpuHistory = Queue();
  final Queue<double> _memoryHistory = Queue();
  final Queue<double> _stressHistory = Queue();
  final Queue<double> _diskHistory = Queue();
  final Queue<double> _stabilityHistory = Queue();

  List<double> get cpuHistory => _cpuHistory.toList();
  List<double> get memoryHistory => _memoryHistory.toList();
  List<double> get stressHistory => _stressHistory.toList();
  List<double> get diskHistory => _diskHistory.toList();
  List<double> get stabilityHistory => _stabilityHistory.toList();

  // ── Processes ──
  List<ProcessImpact> _processes = [];
  List<ProcessImpact> get processes => _processes;

  // ── Events ──
  List<SystemEvent> _events = [];
  List<SystemEvent> get events => _events;

  // ── Subscriptions ──
  StreamSubscription? _liveSub;
  StreamSubscription? _alertSub;
  Timer? _processFetchTimer;
  Timer? _eventFetchTimer;
  Timer? _reconnectTimer;
  Timer? _cooldownTicker;

  /// When true, [_connectionError] may hold a bootstrap failure; do not clear it in [_tryConnect].
  bool _bootstrapErrorPending = false;

  bool _didPullEnginePrefs = false;

  // ── Connection ──

  void connect() {
    unawaited(_bootstrapAndConnect());
  }

  Future<void> reconnect() async {
    _liveSub?.cancel();
    _alertSub?.cancel();
    _processFetchTimer?.cancel();
    _eventFetchTimer?.cancel();
    _reconnectTimer?.cancel();
    _cooldownTicker?.cancel();
    _service.dispose();
    _service = EngineService(port: _settings.lastEngineHttpPort);
    _connected = false;
    _currentState = null;
    _cooldownDeadline = null;
    _bootstrapErrorPending = false;
    _didPullEnginePrefs = false;
    notifyListeners();
    await _bootstrapAndConnect();
  }

  Future<void> _bootstrapAndConnect() async {
    final showChecking = Platform.isWindows &&
        EngineBundledLauncher.bundledEngineExecutablePath() != null;
    if (showChecking) {
      _connectionError = 'Starting engine, please wait…';
      notifyListeners();
    }

    final out = await EngineBundledLauncher.ensureReady(
      preferredPort: _settings.lastEngineHttpPort,
    );

    if (!out.success && (out.message?.isNotEmpty ?? false)) {
      _bootstrapErrorPending = true;
      _connectionError = out.message!;
      notifyListeners();
    } else {
      _bootstrapErrorPending = false;
      if (_connectionError == 'Starting engine, please wait…') {
        _connectionError = '';
      }
    }

    if (out.success) {
      if (out.activePort != _service.port) {
        _service.dispose();
        _service = EngineService(port: out.activePort);
      }
      await _settings.setLastEngineHttpPort(out.activePort);
    }

    _tryConnect();
  }

  void _tryConnect() {
    if (!_bootstrapErrorPending) {
      _connectionError = '';
    }

    try {
      final stream = _service.connectLive();
      _liveSub = stream.listen(
        _onStateReceived,
        onError: (error) {
          _connected = false;
          _bootstrapErrorPending = false;
          _connectionError = 'Connection lost. Retrying...';
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _bootstrapErrorPending = false;
          _connectionError = 'Disconnected. Retrying...';
          notifyListeners();
          _scheduleReconnect();
        },
      );

      _alertSub = _service.connectAlerts().listen(_onAlertPayload);

      _processFetchTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _fetchProcesses(),
      );
      _eventFetchTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _fetchEvents(),
      );

      _connected = true;
      notifyListeners();
      unawaited(_fetchProcesses());
      unawaited(_fetchEvents());
    } catch (e) {
      _connected = false;
      _bootstrapErrorPending = false;
      _connectionError = 'Cannot connect to engine. Is it running?';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _liveSub?.cancel();
      _alertSub?.cancel();
      _processFetchTimer?.cancel();
      _eventFetchTimer?.cancel();
      unawaited(_bootstrapAndConnect());
    });
  }

  void _onAlertPayload(Map<String, dynamic> payload) {
    final message = payload['message'] as String? ?? 'System stress alert';
    if (_settings.desktopNotificationsEnabled) {
      unawaited(_notifications.show(
        title: 'SentraCore alert',
        body:
            message.length > 256 ? '${message.substring(0, 253)}...' : message,
      ));
    }
  }

  void _syncCooldownTicker(SystemState state) {
    _cooldownTicker?.cancel();
    final a = state.alert;
    if (a.inCooldown && a.cooldownRemainingSec > 0) {
      _cooldownDeadline = DateTime.now().add(
        Duration(
          milliseconds:
              (a.cooldownRemainingSec * 1000).round().clamp(0, 86400000),
        ),
      );
      _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_cooldownDeadline == null ||
            !_cooldownDeadline!.isAfter(DateTime.now())) {
          _cooldownTicker?.cancel();
          _cooldownTicker = null;
          _cooldownDeadline = null;
        }
        notifyListeners();
      });
    } else {
      _cooldownDeadline = null;
    }
  }

  // ── Data Handling ──

  Future<void> _maybePullEnginePreferences() async {
    if (_didPullEnginePrefs) return;
    final data = await _service.getUserPreferences();
    if (data == null || data.containsKey('error')) return;
    _didPullEnginePrefs = true;
    _settings.applyFromEngine(data);
    await _settings.save();
    notifyListeners();
  }

  /// Persist [SettingsProvider] values to the engine (and local prefs).
  Future<bool> pushUserPreferences() async {
    final res = await _service.putUserPreferences(_settings.toEngineJson());
    return res != null && res['ok'] == true;
  }

  void _onStateReceived(SystemState state) {
    if (!_didPullEnginePrefs) {
      unawaited(_maybePullEnginePreferences());
    }
    _bootstrapErrorPending = false;
    if (!_connected) {
      _connected = true;
      _connectionError = '';
    }

    _currentState = state;
    _syncCooldownTicker(state);

    // Update history ring buffers
    if (state.normalized != null) {
      _pushHistory(_cpuHistory, state.normalized!.cpu.smoothed);
      _pushHistory(_memoryHistory, state.normalized!.memory.smoothed);
      _pushHistory(
        _diskHistory,
        state.normalized!.diskIo.totalOpsPerSec,
      );
    }
    if (state.stress != null) {
      _pushHistory(_stressHistory, state.stress!.score);
    }
    if (state.stability != null) {
      _pushHistory(_stabilityHistory, state.stability!.score);
    }

    notifyListeners();
  }

  void _pushHistory(Queue<double> queue, double value) {
    queue.addLast(value);
    while (queue.length > _historySize) {
      queue.removeFirst();
    }
  }

  Future<void> _fetchProcesses() async {
    try {
      _processes = await _service.getProcesses(limit: 50);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshProcesses() async {
    await _fetchProcesses();
  }

  Future<void> _fetchEvents() async {
    try {
      _events = await _service.getEvents();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> processAction(int pid, String action) async {
    final r = await _service.postProcessAction(pid, action);
    await _fetchProcesses();
    notifyListeners();
    return r ?? {'ok': false, 'error': 'No response'};
  }

  // ── Cleanup ──

  @override
  void dispose() {
    _liveSub?.cancel();
    _alertSub?.cancel();
    _processFetchTimer?.cancel();
    _eventFetchTimer?.cancel();
    _reconnectTimer?.cancel();
    _cooldownTicker?.cancel();
    _service.dispose();
    super.dispose();
  }
}
