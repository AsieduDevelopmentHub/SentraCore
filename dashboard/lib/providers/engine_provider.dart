import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/services/engine_service.dart';

/// Central state management for the SentraCore dashboard.
///
/// Connects to the Python engine via WebSocket, maintains a history
/// of system states for charting, and exposes reactive state to the UI.
class EngineProvider extends ChangeNotifier {
  final EngineService _service = EngineService();

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
  EngineInfo? get engineInfo => _currentState?.engine;

  // ── History for Charts (last 60 data points = ~2 minutes) ──
  static const int _historySize = 60;

  final Queue<double> _cpuHistory = Queue();
  final Queue<double> _memoryHistory = Queue();
  final Queue<double> _stressHistory = Queue();
  final Queue<double> _diskHistory = Queue();

  List<double> get cpuHistory => _cpuHistory.toList();
  List<double> get memoryHistory => _memoryHistory.toList();
  List<double> get stressHistory => _stressHistory.toList();
  List<double> get diskHistory => _diskHistory.toList();

  // ── Processes ──
  List<ProcessImpact> _processes = [];
  List<ProcessImpact> get processes => _processes;

  // ── Events ──
  List<SystemEvent> _events = [];
  List<SystemEvent> get events => _events;

  // ── Subscriptions ──
  StreamSubscription? _liveSub;
  Timer? _processFetchTimer;
  Timer? _eventFetchTimer;
  Timer? _reconnectTimer;

  // ── Connection ──

  void connect() {
    _tryConnect();
  }

  void _tryConnect() {
    _connectionError = '';

    try {
      final stream = _service.connectLive();
      _liveSub = stream.listen(
        _onStateReceived,
        onError: (error) {
          _connected = false;
          _connectionError = 'Connection lost. Retrying...';
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _connectionError = 'Disconnected. Retrying...';
          notifyListeners();
          _scheduleReconnect();
        },
      );

      // Fetch processes and events periodically via REST
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
    } catch (e) {
      _connected = false;
      _connectionError = 'Cannot connect to engine. Is it running?';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _liveSub?.cancel();
      _processFetchTimer?.cancel();
      _eventFetchTimer?.cancel();
      _tryConnect();
    });
  }

  // ── Data Handling ──

  void _onStateReceived(SystemState state) {
    if (!_connected) {
      _connected = true;
      _connectionError = '';
    }

    _currentState = state;

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
      _processes = await _service.getProcesses();
      // Don't notify here — the live stream already triggers rebuilds
    } catch (_) {}
  }

  Future<void> _fetchEvents() async {
    try {
      _events = await _service.getEvents();
    } catch (_) {}
  }

  // ── Cleanup ──

  @override
  void dispose() {
    _liveSub?.cancel();
    _processFetchTimer?.cancel();
    _eventFetchTimer?.cancel();
    _reconnectTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}
