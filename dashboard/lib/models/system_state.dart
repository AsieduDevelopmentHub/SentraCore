// Data models mirroring the Python engine's API responses.
class SystemState {
  final EngineInfo engine;
  final StressResult? stress;
  final NormalizedData? normalized;
  final AlertInfo alert;
  final BufferInfo buffers;

  SystemState({
    required this.engine,
    this.stress,
    this.normalized,
    required this.alert,
    required this.buffers,
  });

  factory SystemState.fromJson(Map<String, dynamic> json) {
    return SystemState(
      engine: EngineInfo.fromJson(json['engine'] ?? {}),
      stress: json['stress'] != null
          ? StressResult.fromJson(json['stress'])
          : null,
      normalized: json['normalized'] != null
          ? NormalizedData.fromJson(json['normalized'])
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
        (json['pressures'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      weights: Map<String, double>.from(
        (json['weights'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
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

class AlertInfo {
  final int totalFired;
  final bool inCooldown;
  final int consecutiveHigh;

  AlertInfo({
    required this.totalFired,
    required this.inCooldown,
    required this.consecutiveHigh,
  });

  factory AlertInfo.fromJson(Map<String, dynamic> json) {
    return AlertInfo(
      totalFired: json['total_fired'] ?? 0,
      inCooldown: json['in_cooldown'] ?? false,
      consecutiveHigh: json['consecutive_high'] ?? 0,
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
  final Map<String, dynamic> details;

  SystemEvent({
    required this.timestamp,
    required this.eventType,
    required this.severity,
    required this.details,
  });

  factory SystemEvent.fromJson(Map<String, dynamic> json) {
    return SystemEvent(
      timestamp: (json['timestamp'] ?? 0).toDouble(),
      eventType: json['event_type'] ?? 'unknown',
      severity: json['severity'] ?? 'info',
      details: Map<String, dynamic>.from(json['details'] ?? {}),
    );
  }
}
