class HistoryProcessSample {
  final String name;
  final int pid;
  final double cpuPercent;
  final double memPercent;
  final double impact;

  const HistoryProcessSample({
    required this.name,
    required this.pid,
    required this.cpuPercent,
    required this.memPercent,
    required this.impact,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'pid': pid,
        'cpu_percent': cpuPercent,
        'mem_percent': memPercent,
        'impact': impact,
      };

  factory HistoryProcessSample.fromJson(Map<String, dynamic> json) {
    return HistoryProcessSample(
      name: '${json['name'] ?? ''}',
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0,
      memPercent: (json['mem_percent'] as num?)?.toDouble() ?? 0,
      impact: (json['impact'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HistorySample {
  final DateTime at;
  final double cpuPercent;
  final double memPercent;
  final double diskPressurePercent;
  final List<HistoryProcessSample> topProcesses;

  const HistorySample({
    required this.at,
    required this.cpuPercent,
    required this.memPercent,
    required this.diskPressurePercent,
    required this.topProcesses,
  });

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'cpu_percent': cpuPercent,
        'mem_percent': memPercent,
        'disk_pressure_percent': diskPressurePercent,
        'top_processes': topProcesses.map((p) => p.toJson()).toList(),
      };

  factory HistorySample.fromJson(Map<String, dynamic> json) {
    final atRaw = json['at'];
    final at = atRaw is String
        ? (DateTime.tryParse(atRaw) ?? DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);
    final procsRaw = json['top_processes'];
    final procs = <HistoryProcessSample>[];
    if (procsRaw is List) {
      for (final x in procsRaw) {
        if (x is Map) {
          procs
              .add(HistoryProcessSample.fromJson(Map<String, dynamic>.from(x)));
        }
      }
    }
    return HistorySample(
      at: at,
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0,
      memPercent: (json['mem_percent'] as num?)?.toDouble() ?? 0,
      diskPressurePercent:
          (json['disk_pressure_percent'] as num?)?.toDouble() ?? 0,
      topProcesses: procs,
    );
  }
}
