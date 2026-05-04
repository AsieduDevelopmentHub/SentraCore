// Data models mirroring the Python engine's API responses.
class SystemState {
  final EngineInfo engine;
  final StressResult? stress;
  final NormalizedData? normalized;
  final TrendResult? trend;
  final AnomalyResult? anomaly;
  final PredictionResult? prediction;
  final StabilityIndex? stability;
  final AlertInfo alert;
  final BufferInfo buffers;

  SystemState({
    required this.engine,
    this.stress,
    this.normalized,
    this.trend,
    this.anomaly,
    this.prediction,
    this.stability,
    required this.alert,
    required this.buffers,
  });

  factory SystemState.fromJson(Map<String, dynamic> json) {
    return SystemState(
      engine: EngineInfo.fromJson(json['engine'] ?? {}),
      stress:
          json['stress'] != null ? StressResult.fromJson(json['stress']) : null,
      normalized: json['normalized'] != null
          ? NormalizedData.fromJson(json['normalized'])
          : null,
      trend: json['trend'] != null ? TrendResult.fromJson(json['trend']) : null,
      anomaly: json['anomaly'] != null
          ? AnomalyResult.fromJson(json['anomaly'])
          : null,
      prediction: json['prediction'] != null
          ? PredictionResult.fromJson(json['prediction'])
          : null,
      stability: json['stability'] != null
          ? StabilityIndex.fromJson(json['stability'])
          : null,
      alert: AlertInfo.fromJson(json['alert'] ?? {}),
      buffers: BufferInfo.fromJson(json['buffers'] ?? {}),
    );
  }
}

class EngineInfo {
  final String version;
  final int uptimeSamples;
  final bool baselineReady;
  final int baselineSamples;

  EngineInfo({
    required this.version,
    required this.uptimeSamples,
    required this.baselineReady,
    required this.baselineSamples,
  });

  factory EngineInfo.fromJson(Map<String, dynamic> json) {
    return EngineInfo(
      version: json['version'] ?? '0.0.0',
      uptimeSamples: json['uptime_samples'] ?? 0,
      baselineReady: json['baseline_ready'] ?? false,
      baselineSamples: json['baseline_samples'] ?? 0,
    );
  }
}

class StressResult {
  final double score;
  final String level;
  final Map<String, double> pressures;
  final Map<String, double> weights;

  StressResult({
    required this.score,
    required this.level,
    required this.pressures,
    required this.weights,
  });

  factory StressResult.fromJson(Map<String, dynamic> json) {
    return StressResult(
      score: (json['score'] ?? 0).toDouble(),
      level: json['level'] ?? 'unknown',
      pressures: Map<String, double>.from(
        (json['pressures'] ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      weights: Map<String, double>.from(
        (json['weights'] ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
    );
  }
}

class NormalizedData {
  final double timestamp;
  final CpuData cpu;
  final MemoryData memory;
  final double swapPercent;
  final DiskIoData diskIo;

  NormalizedData({
    required this.timestamp,
    required this.cpu,
    required this.memory,
    required this.swapPercent,
    required this.diskIo,
  });

  factory NormalizedData.fromJson(Map<String, dynamic> json) {
    return NormalizedData(
      timestamp: (json['timestamp'] ?? 0).toDouble(),
      cpu: CpuData.fromJson(json['cpu'] ?? {}),
      memory: MemoryData.fromJson(json['memory'] ?? {}),
      swapPercent: (json['swap_percent'] ?? 0).toDouble(),
      diskIo: DiskIoData.fromJson(json['disk_io'] ?? {}),
    );
  }
}

class CpuData {
  final double raw;
  final double smoothed;
  final bool spiking;

  CpuData({required this.raw, required this.smoothed, required this.spiking});

  factory CpuData.fromJson(Map<String, dynamic> json) {
    return CpuData(
      raw: (json['raw'] ?? 0).toDouble(),
      smoothed: (json['smoothed'] ?? 0).toDouble(),
      spiking: json['spiking'] ?? false,
    );
  }
}

class MemoryData {
  final double raw;
  final double smoothed;
  final int used;
  final int available;
  final int total;
  final bool spiking;

  MemoryData({
    required this.raw,
    required this.smoothed,
    required this.used,
    required this.available,
    required this.total,
    required this.spiking,
  });

  factory MemoryData.fromJson(Map<String, dynamic> json) {
    return MemoryData(
      raw: (json['raw'] ?? 0).toDouble(),
      smoothed: (json['smoothed'] ?? 0).toDouble(),
      used: json['used'] ?? 0,
      available: json['available'] ?? 0,
      total: json['total'] ?? 0,
      spiking: json['spiking'] ?? false,
    );
  }
}

class DiskIoData {
  final double readBytesPerSec;
  final double writeBytesPerSec;
  final double totalOpsPerSec;
  final bool spiking;

  DiskIoData({
    required this.readBytesPerSec,
    required this.writeBytesPerSec,
    required this.totalOpsPerSec,
    required this.spiking,
  });

  factory DiskIoData.fromJson(Map<String, dynamic> json) {
    return DiskIoData(
      readBytesPerSec: (json['read_bytes_per_sec'] ?? 0).toDouble(),
      writeBytesPerSec: (json['write_bytes_per_sec'] ?? 0).toDouble(),
      totalOpsPerSec: (json['total_ops_per_sec'] ?? 0).toDouble(),
      spiking: json['spiking'] ?? false,
    );
  }
}

/// One fired resource alert (from engine history).
class AlertRecord {
  final double timestamp;
  final double stressScore;
  final String level;
  final String message;

  AlertRecord({
    required this.timestamp,
    required this.stressScore,
    required this.level,
    required this.message,
  });

  factory AlertRecord.fromJson(Map<String, dynamic> json) {
    return AlertRecord(
      timestamp: (json['timestamp'] ?? 0).toDouble(),
      stressScore: (json['stress_score'] ?? 0).toDouble(),
      level: json['level']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class AlertInfo {
  final int totalFired;
  final bool inCooldown;
  final double cooldownTotalSec;
  final double cooldownRemainingSec;
  final int consecutiveHigh;
  final String? lastMessage;
  final RootCauseAnalysis? lastRootCause;
  final List<AlertRecord> recentAlerts;

  AlertInfo({
    required this.totalFired,
    required this.inCooldown,
    this.cooldownTotalSec = 0,
    this.cooldownRemainingSec = 0,
    required this.consecutiveHigh,
    this.lastMessage,
    this.lastRootCause,
    this.recentAlerts = const [],
  });

  factory AlertInfo.fromJson(Map<String, dynamic> json) {
    final recent = json['recent_alerts'];
    return AlertInfo(
      totalFired: json['total_fired'] ?? 0,
      inCooldown: json['in_cooldown'] ?? false,
      cooldownTotalSec: (json['cooldown_total_sec'] ?? 0).toDouble(),
      cooldownRemainingSec: (json['cooldown_remaining_sec'] ?? 0).toDouble(),
      consecutiveHigh: json['consecutive_high'] ?? 0,
      lastMessage:
          json['last_alert'] != null ? json['last_alert']['message'] : null,
      lastRootCause:
          json['last_alert'] != null && json['last_alert']['root_cause'] != null
              ? RootCauseAnalysis.fromJson(json['last_alert']['root_cause'])
              : null,
      recentAlerts: recent is List
          ? recent
              .whereType<Map>()
              .map((e) => AlertRecord.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class RootCauseAnalysis {
  final String primaryBottleneck;
  final Map<String, dynamic>? suspectProcess;
  final Map<String, dynamic>? triggerEvent;
  final double confidenceScore;
  final String summary;

  RootCauseAnalysis({
    required this.primaryBottleneck,
    this.suspectProcess,
    this.triggerEvent,
    required this.confidenceScore,
    required this.summary,
  });

  factory RootCauseAnalysis.fromJson(Map<String, dynamic> json) {
    return RootCauseAnalysis(
      primaryBottleneck: json['primary_bottleneck'] ?? 'unknown',
      suspectProcess: json['suspect_process'],
      triggerEvent: json['trigger_event'],
      confidenceScore: (json['confidence_score'] ?? 0).toDouble(),
      summary: json['summary'] ?? '',
    );
  }
}

class BufferInfo {
  final BufferDetail short;
  final BufferDetail long;

  BufferInfo({required this.short, required this.long});

  factory BufferInfo.fromJson(Map<String, dynamic> json) {
    return BufferInfo(
      short: BufferDetail.fromJson(json['short'] ?? {}),
      long: BufferDetail.fromJson(json['long'] ?? {}),
    );
  }
}

class BufferDetail {
  final int count;
  final int capacity;

  BufferDetail({required this.count, required this.capacity});

  factory BufferDetail.fromJson(Map<String, dynamic> json) {
    return BufferDetail(
      count: json['count'] ?? 0,
      capacity: json['capacity'] ?? 0,
    );
  }
}

class ProcessImpact {
  final int pid;
  final String name;
  final double avgCpuPercent;
  final double avgMemoryPercent;
  final double peakCpuPercent;
  final double currentCpuPercent;
  final double currentMemoryPercent;
  final double impactScore;

  // Convenience getters used by the processes screen.
  double get cpuImpact => currentCpuPercent;
  double get memoryPercent => currentMemoryPercent;

  ProcessImpact({
    required this.pid,
    required this.name,
    required this.avgCpuPercent,
    required this.avgMemoryPercent,
    required this.peakCpuPercent,
    required this.currentCpuPercent,
    required this.currentMemoryPercent,
    required this.impactScore,
  });

  factory ProcessImpact.fromJson(Map<String, dynamic> json) {
    return ProcessImpact(
      pid: json['pid'] ?? 0,
      name: json['name'] ?? 'Unknown',
      avgCpuPercent: (json['avg_cpu_percent'] ?? 0).toDouble(),
      avgMemoryPercent: (json['avg_memory_percent'] ?? 0).toDouble(),
      peakCpuPercent: (json['peak_cpu_percent'] ?? 0).toDouble(),
      currentCpuPercent: (json['current_cpu_percent'] ?? 0).toDouble(),
      currentMemoryPercent: (json['current_memory_percent'] ?? 0).toDouble(),
      impactScore: (json['impact_score'] ?? 0).toDouble(),
    );
  }
}

class SystemEvent {
  final double timestamp;
  final String eventType;
  final String severity;
  final String description;
  final Map<String, dynamic> details;

  SystemEvent({
    required this.timestamp,
    required this.eventType,
    required this.severity,
    required this.description,
    required this.details,
  });

  factory SystemEvent.fromJson(Map<String, dynamic> json) {
    final details = Map<String, dynamic>.from(json['details'] ?? {});
    return SystemEvent(
      timestamp: (json['timestamp'] ?? 0).toDouble(),
      eventType: json['event_type'] ?? 'unknown',
      severity: json['severity'] ?? 'info',
      description: details['description'] as String? ??
          details['message'] as String? ??
          '',
      details: details,
    );
  }
}

class PredictionResult {
  final double? memoryExhaustionEtaSec;
  final double? cpuCriticalEtaSec;
  final double riskScore;

  PredictionResult({
    this.memoryExhaustionEtaSec,
    this.cpuCriticalEtaSec,
    required this.riskScore,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      memoryExhaustionEtaSec: json['memory_exhaustion_eta_sec']?.toDouble(),
      cpuCriticalEtaSec: json['cpu_critical_eta_sec']?.toDouble(),
      riskScore: (json['risk_score'] ?? 0).toDouble(),
    );
  }
}

class StabilityIndex {
  final double score;
  final String state;
  final Map<String, dynamic> components;

  StabilityIndex({
    required this.score,
    required this.state,
    required this.components,
  });

  factory StabilityIndex.fromJson(Map<String, dynamic> json) {
    return StabilityIndex(
      score: (json['score'] ?? 100).toDouble(),
      state: json['state'] ?? 'unknown',
      components: Map<String, dynamic>.from(json['components'] ?? {}),
    );
  }
}

/// Trend analysis result from the Python TrendAnalyzer.
class TrendResult {
  final double cpuSlope;
  final double memorySlope;
  final double cpuVolatility;
  final double memoryVolatility;

  TrendResult({
    required this.cpuSlope,
    required this.memorySlope,
    required this.cpuVolatility,
    required this.memoryVolatility,
  });

  factory TrendResult.fromJson(Map<String, dynamic> json) {
    return TrendResult(
      cpuSlope: (json['cpu_slope'] ?? 0).toDouble(),
      memorySlope: (json['memory_slope'] ?? 0).toDouble(),
      cpuVolatility: (json['cpu_volatility'] ?? 0).toDouble(),
      memoryVolatility: (json['memory_volatility'] ?? 0).toDouble(),
    );
  }
}

/// Anomaly detection result from the Python AnomalyDetector.
class AnomalyResult {
  final double score;
  final bool isSustained;
  final double cpuZScore;
  final double memoryZScore;
  final double diskZScore;
  final String level;

  AnomalyResult({
    this.score = 0,
    this.isSustained = false,
    required this.cpuZScore,
    required this.memoryZScore,
    required this.diskZScore,
    required this.level,
  });

  factory AnomalyResult.fromJson(Map<String, dynamic> json) {
    double cpuZ;
    double memZ;
    double diskZ;
    final zs = json['z_scores'];
    if (zs is Map) {
      cpuZ = ((zs['cpu'] ?? 0) as num).toDouble().abs();
      memZ = ((zs['memory'] ?? 0) as num).toDouble().abs();
      diskZ = ((zs['disk'] ?? 0) as num).toDouble().abs();
    } else {
      cpuZ = (json['cpu_z_score'] ?? json['cpu_zscore'] ?? 0).toDouble().abs();
      memZ = (json['memory_z_score'] ?? json['memory_zscore'] ?? 0)
          .toDouble()
          .abs();
      diskZ =
          (json['disk_z_score'] ?? json['disk_zscore'] ?? 0).toDouble().abs();
    }

    return AnomalyResult(
      score: (json['score'] ?? 0).toDouble(),
      isSustained: json['is_sustained'] == true,
      cpuZScore: cpuZ,
      memoryZScore: memZ,
      diskZScore: diskZ,
      level: json['level']?.toString() ?? 'normal',
    );
  }
}
