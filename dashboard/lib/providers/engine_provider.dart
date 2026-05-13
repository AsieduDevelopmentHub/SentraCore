import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/providers/history_provider.dart';
import 'package:sentracore_dashboard/providers/settings_provider.dart';
import 'package:sentracore_dashboard/services/desktop_notification_service.dart';
import 'package:sentracore_dashboard/services/engine_bundled_launcher.dart';
import 'package:sentracore_dashboard/services/engine_config_store.dart';
import 'package:sentracore_dashboard/services/engine_service.dart';

/// Central state management for the SentraCore dashboard.
///
/// Connects to the Python engine via WebSocket, maintains a history
/// of system states for charting, and exposes reactive state to the UI.
class EngineProvider extends ChangeNotifier {
  EngineProvider({
    required SettingsProvider settings,
    required DesktopNotificationService notifications,
    HistoryProvider? history,
  })  : _settings = settings,
        _notifications = notifications,
        _history = history {
    final disk = EngineConfigStore.tryReadSync();
    _service = EngineService(
      host: disk?.host ?? EngineConfigStore.connectHostForUi(),
      port: disk?.port ?? 8740,
    );
  }

  final SettingsProvider _settings;
  final DesktopNotificationService _notifications;
  final HistoryProvider? _history;
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

  /// Each [/ws/alerts] push (one per fired alert). Merged with engine [recent_alerts] for UI.
  static const int _maxAlertFeed = 120;
  final List<AlertRecord> _alertFeedFromWs = [];

  /// Newest-first list for Diagnostics; deduped against live state history.
  List<AlertRecord> get mergedAlertHistory {
    final fromEngine =
        _currentState?.alert.recentAlerts ?? const <AlertRecord>[];
    final seen = <String>{};
    String dedupeKey(AlertRecord r) =>
        '${r.timestamp.toStringAsFixed(3)}::${r.message}';
    final merged = <AlertRecord>[];
    for (final r in [..._alertFeedFromWs, ...fromEngine]) {
      if (seen.add(dedupeKey(r))) {
        merged.add(r);
      }
    }
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  // ── Subscriptions ──
  StreamSubscription? _liveSub;
  StreamSubscription? _alertSub;
  Timer? _processFetchTimer;
  Timer? _eventFetchTimer;
  Timer? _reconnectTimer;
  Timer? _cooldownTicker;
  Timer? _liveDataWatchdog;
  Timer? _engineHealthWatchdog;

  /// Last successful [/ws/live] payload, or null until the first frame after subscribe.
  DateTime? _lastLiveStateAt;

  /// When the current live WebSocket subscription was opened.
  DateTime? _wsSubscribeAt;

  /// Throttle bundled-engine kills from the stale-data watchdog.
  DateTime? _lastBundledEngineKillAttempt;

  static const Duration _liveDataStaleThreshold = Duration(seconds: 30);
  static const Duration _liveDataWatchdogInterval = Duration(seconds: 8);
  static const Duration _bundledEngineKillCooldown = Duration(seconds: 50);

  bool _recoveringLive = false;

  /// When true, [_connectionError] may hold a bootstrap failure; do not clear it in [_tryConnect].
  bool _bootstrapErrorPending = false;

  bool _didPullEnginePrefs = false;

  // ── Connection ──

  void connect() {
    unawaited(_bootstrapAndConnect());
  }

  Future<void> reconnect() async {
    _alertFeedFromWs.clear();
    _liveDataWatchdog?.cancel();
    _liveDataWatchdog = null;
    _liveSub?.cancel();
    _alertSub?.cancel();
    _processFetchTimer?.cancel();
    _eventFetchTimer?.cancel();
    _reconnectTimer?.cancel();
    _cooldownTicker?.cancel();
    _engineHealthWatchdog?.cancel();
    _service.dispose();
    final cfg = await EngineConfigStore.readOrCreate();
    _service = EngineService(host: cfg.host, port: cfg.port);
    _connected = false;
    _currentState = null;
    _cooldownDeadline = null;
    _bootstrapErrorPending = false;
    _didPullEnginePrefs = false;
    notifyListeners();
    await _bootstrapAndConnect();
  }

  Future<void> _bootstrapAndConnect() async {
    final showChecking =
        EngineBundledLauncher.bundledEngineExecutablePath() != null;
    if (showChecking) {
      _connectionError = 'Starting engine, please wait…';
      notifyListeners();
    }

    final diskPre = await EngineConfigStore.read();
    final userRetry = diskPre?.status == EngineStatus.failed;
    final out = await EngineBundledLauncher.ensureReady(userRetry: userRetry);

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
      if (out.activePort != _service.port || out.activeHost != _service.host) {
        _service.dispose();
        _service = EngineService(host: out.activeHost, port: out.activePort);
      }
      _tryConnect();
      return;
    }

    notifyListeners();
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
          _liveDataWatchdog?.cancel();
          _liveDataWatchdog = null;
          _connected = false;
          _bootstrapErrorPending = false;
          _connectionError = 'Connection lost. Retrying...';
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          _liveDataWatchdog?.cancel();
          _liveDataWatchdog = null;
          _connected = false;
          _bootstrapErrorPending = false;
          _connectionError = 'Disconnected. Retrying...';
          notifyListeners();
          _scheduleReconnect();
        },
      );

      // Keep alert channel failures from bubbling as uncaught async errors.
      // Live telemetry drives overall connectivity/reconnects.
      _alertSub = _service.connectAlerts().listen(
            _onAlertPayload,
            onError: (_) {},
            onDone: () {},
          );

      _processFetchTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _fetchProcesses(),
      );
      _eventFetchTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _fetchEvents(),
      );

      // Health watchdog: if the engine is killed externally (Task Manager) or
      // stops responding, attempt a bounded restart/reconnect.
      _engineHealthWatchdog?.cancel();
      _engineHealthWatchdog = Timer.periodic(
        const Duration(seconds: 6),
        (_) => unawaited(_engineHealthTick()),
      );

      // Stay "disconnected" in UI until first live frame arrives (avoids false
      // positive if the socket dies immediately after subscribe).
      _connected = false;
      _wsSubscribeAt = DateTime.now();
      _lastLiveStateAt = null;
      _liveDataWatchdog?.cancel();
      _liveDataWatchdog = Timer.periodic(
        _liveDataWatchdogInterval,
        (_) => _checkLiveDataStale(),
      );
      notifyListeners();
      unawaited(_fetchProcesses());
      unawaited(_fetchEvents());
    } catch (e) {
      _liveDataWatchdog?.cancel();
      _liveDataWatchdog = null;
      _connected = false;
      _bootstrapErrorPending = false;
      _connectionError = 'Cannot connect to engine. Is it running?';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  Future<void> _engineHealthTick() async {
    // Avoid piling reconnects; reuse the same bootstrap + connect path.
    if (_recoveringLive) return;
    if (_bootstrapErrorPending) return;
    if (_reconnectTimer != null) return;

    try {
      final j = await _service.getHealth();
      if (j != null && j['engine'] == true) return;
    } catch (_) {
      // treat as unhealthy
    }

    // Engine is down or unhealthy: restart/reconnect.
    _connected = false;
    _connectionError = 'Engine stopped; restarting…';
    notifyListeners();
    _scheduleReconnect();
  }

  void _checkLiveDataStale() {
    if (_liveSub == null || _recoveringLive) return;
    final reference = _lastLiveStateAt ?? _wsSubscribeAt;
    if (reference == null) return;
    if (DateTime.now().difference(reference) < _liveDataStaleThreshold) {
      return;
    }
    final lastKill = _lastBundledEngineKillAttempt;
    if (lastKill != null &&
        DateTime.now().difference(lastKill) < _bundledEngineKillCooldown) {
      return;
    }
    unawaited(_maybeRecoverStalledLiveChannel());
  }

  /// Only treat missing live frames as a hung engine if HTTP health still says the
  /// engine is up. If the process was killed externally, health is down — let the
  /// normal reconnect path run instead of [recoverOwnedAfterStall], which uses
  /// [forceRestart] and can burn through the launcher's restart budget.
  Future<void> _maybeRecoverStalledLiveChannel() async {
    if (_recoveringLive) return;
    try {
      final j = await _service.getHealth();
      if (j == null || j['engine'] != true) {
        return;
      }
    } catch (_) {
      return;
    }
    await _recoverStalledLiveChannel();
  }

  /// HTTP/WS up but no live telemetry (hung orchestrator): restart bundled engine
  /// on Windows, then bootstrap again.
  Future<void> _recoverStalledLiveChannel() async {
    if (_recoveringLive) return;
    _recoveringLive = true;
    _liveDataWatchdog?.cancel();
    _liveDataWatchdog = null;
    _reconnectTimer?.cancel();
    _lastBundledEngineKillAttempt = DateTime.now();
    try {
      _connected = false;
      _connectionError = 'No live data from engine; restarting engine…';
      notifyListeners();

      await EngineBundledLauncher.recoverOwnedAfterStall();

      _liveSub?.cancel();
      _alertSub?.cancel();
      _processFetchTimer?.cancel();
      _eventFetchTimer?.cancel();

      await _bootstrapAndConnect();
    } finally {
      _recoveringLive = false;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_reconnectTick());
    });
  }

  Future<void> _reconnectTick() async {
    _liveDataWatchdog?.cancel();
    _liveDataWatchdog = null;
    _liveSub?.cancel();
    _alertSub?.cancel();
    _processFetchTimer?.cancel();
    _eventFetchTimer?.cancel();
    await _bootstrapAndConnect();
  }

  void _onAlertPayload(Map<String, dynamic> payload) {
    try {
      _alertFeedFromWs.insert(0, AlertRecord.fromJson(payload));
      if (_alertFeedFromWs.length > _maxAlertFeed) {
        _alertFeedFromWs.removeRange(_maxAlertFeed, _alertFeedFromWs.length);
      }
    } catch (_) {}
    final message = payload['message'] as String? ?? 'System stress alert';
    if (_settings.desktopNotificationsEnabled) {
      unawaited(_notifications.show(
        title: 'SentraCore alert',
        body:
            message.length > 256 ? '${message.substring(0, 253)}...' : message,
      ));
    }
    notifyListeners();
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
    _lastLiveStateAt = DateTime.now();
    _history?.recordIfDue(
      now: _lastLiveStateAt!,
      state: state,
      processes: _processes,
    );
    if (!_didPullEnginePrefs) {
      unawaited(_maybePullEnginePreferences());
    }
    _bootstrapErrorPending = false;
    if (!_connected) {
      _connected = true;
      _connectionError = '';
      // Once we are talking to the engine, pull the authoritative history
      // archive so charts survive a dashboard restart even if SharedPreferences
      // is empty (e.g. after `flutter clean` or a fresh install).
      _history?.startPeriodicRefresh(_service);
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
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> processAction(int pid, String action) async {
    final r = await _service.postProcessAction(pid, action);
    await _fetchProcesses();
    notifyListeners();
    return r ?? {'ok': false, 'error': 'No response'};
  }

  // ── Datastore (history, cache, baseline) ──

  /// Fetch on-disk layout + history summary from the engine.
  Future<Map<String, dynamic>?> getStorageInfo() {
    return _service.getStorageInfo();
  }

  /// Delete every file under the engine's cache/ directory.
  Future<Map<String, dynamic>?> clearEngineCache() async {
    final r = await _service.clearCache();
    notifyListeners();
    return r;
  }

  /// Wipe the engine-side history archive AND the dashboard's offline mirror.
  Future<Map<String, dynamic>?> clearAllHistory() async {
    final r = await _service.deleteHistory();
    _history?.clear();
    notifyListeners();
    return r;
  }

  /// Reset the behavioral baseline (engine continues running).
  Future<Map<String, dynamic>?> resetEngineBaseline() async {
    final r = await _service.resetBaseline();
    notifyListeners();
    return r;
  }

  /// Pull the latest history window from the engine immediately.
  Future<void> refreshHistoryNow() async {
    await _history?.refreshFromEngine(_service);
  }

  // ── Disk cleanup + large file finder ──

  Future<Map<String, dynamic>?> getCleanupCategories() {
    return _service.getCleanupCategories();
  }

  Future<Map<String, dynamic>?> runCleanupScan({List<String>? categoryIds}) {
    return _service.runCleanupScan(categoryIds: categoryIds);
  }

  Future<Map<String, dynamic>?> applyCleanup({
    required String scanId,
    required List<String> categoryIds,
    String mode = 'recycle',
  }) {
    return _service.applyCleanup(
      scanId: scanId,
      categoryIds: categoryIds,
      mode: mode,
    );
  }

  Future<Map<String, dynamic>?> findLargeFiles({
    required String path,
    double minMb = 100.0,
    int limit = 200,
  }) {
    return _service.findLargeFiles(path: path, minMb: minMb, limit: limit);
  }

  /// Hardware health (CPU / memory / disks) from the engine.
  Future<Map<String, dynamic>?> getHardwareHealth({bool refresh = false}) {
    return _service.getHardwareHealth(refresh: refresh);
  }

  // ── Cleanup ──

  @override
  void dispose() {
    _liveDataWatchdog?.cancel();
    _engineHealthWatchdog?.cancel();
    _liveSub?.cancel();
    _alertSub?.cancel();
    _processFetchTimer?.cancel();
    _eventFetchTimer?.cancel();
    _reconnectTimer?.cancel();
    _cooldownTicker?.cancel();
    _history?.stopPeriodicRefresh();
    _service.dispose();
    // Do NOT kill the engine on app close. The engine is designed to be a
    // background component and should survive dashboard restarts.
    super.dispose();
  }
}
