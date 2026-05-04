class LogbookEntry {
  final String id;
  final DateTime at;
  final String processName;
  final double cpuPercent;
  final double memPercent;
  final double diskPressurePercent;
  final String notes;

  const LogbookEntry({
    required this.id,
    required this.at,
    required this.processName,
    required this.cpuPercent,
    required this.memPercent,
    required this.diskPressurePercent,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'at': at.toIso8601String(),
      'process_name': processName,
      'cpu_percent': cpuPercent,
      'mem_percent': memPercent,
      'disk_pressure_percent': diskPressurePercent,
      'notes': notes,
    };
  }

  factory LogbookEntry.fromJson(Map<String, dynamic> json) {
    final atRaw = json['at'];
    DateTime at;
    if (atRaw is String) {
      at = DateTime.tryParse(atRaw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      at = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return LogbookEntry(
      id: '${json['id'] ?? ''}'.trim().isEmpty ? 'unknown' : '${json['id']}',
      at: at,
      processName: '${json['process_name'] ?? ''}'.trim(),
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0,
      memPercent: (json['mem_percent'] as num?)?.toDouble() ?? 0,
      diskPressurePercent:
          (json['disk_pressure_percent'] as num?)?.toDouble() ?? 0,
      notes: '${json['notes'] ?? ''}',
    );
  }
}
