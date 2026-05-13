import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/services/hardware_health_cache.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Hardware health (CPU, RAM, and storage). Engine probes can take 10–20s;
/// the screen shows the last successful snapshot from disk immediately, then
/// refreshes periodically (the engine caches probe results for ~30s).
class HardwareScreen extends StatefulWidget {
  const HardwareScreen({super.key});

  @override
  State<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends State<HardwareScreen> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;
  String? _softWarning;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
    _ticker = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_refresh(refresh: false));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final cached = await HardwareHealthCache.read();
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _report = cached;
        _error = null;
      });
    }
    await _refresh(refresh: false);
  }

  String? _cacheAgeLabel(Map<String, dynamic> m) {
    final ms = (m['cached_at_ms'] as num?)?.toInt();
    if (ms == null) return 'Showing last saved snapshot';
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (age.inMinutes < 2) return 'Showing last saved snapshot';
    return 'Showing last saved snapshot (${age.inMinutes} min ago)';
  }

  Future<void> _refresh({required bool refresh}) async {
    setState(() {
      _loading = true;
      _softWarning = null;
    });
    final engine = context.read<EngineProvider>();
    final data = await engine.getHardwareHealth(refresh: refresh);
    if (!mounted) return;

    if (data != null && data['ok'] == true) {
      final stored = await HardwareHealthCache.write(data);
      if (!mounted) return;
      setState(() {
        _report = stored ?? data;
        _error = null;
        _softWarning = null;
        _loading = false;
      });
      return;
    }

    final err = (data?['error'] as String?) ?? 'Could not reach the engine.';
    final hasDisplayable = _report != null && _report!['ok'] == true;

    setState(() {
      _loading = false;
      if (hasDisplayable) {
        _error = null;
        _softWarning =
            'Live refresh failed: $err. Showing last good data below.';
      } else {
        _error = err;
        _softWarning = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final components = report?['components'] as Map<String, dynamic>?;
    final cpu = components?['cpu'] as Map<String, dynamic>?;
    final memory = components?['memory'] as Map<String, dynamic>?;
    final disks = components?['disks'] as Map<String, dynamic>?;
    final overall = report?['overall'] as String? ?? 'unknown';
    final showHardError =
        _error != null && (report == null || report['ok'] != true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HardwareHeader(
            overall: overall,
            loading: _loading,
            staleLabel: _headerSubtitle(report),
            onRefresh: () => _refresh(refresh: true),
          ),
          if (showHardError) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ],
          if (_softWarning != null &&
              report != null &&
              report['ok'] == true) ...[
            const SizedBox(height: 6),
            Text(
              _softWarning!,
              style: TextStyle(
                color: AppTheme.warning,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: report == null || report['ok'] != true
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text(
                            'No hardware data yet. Tap refresh.',
                            style: TextStyle(
                              color: AppTheme.textMutedFor(context),
                            ),
                          ),
                  )
                : ListView(
                    children: [
                      _CpuCard(data: cpu),
                      const SizedBox(height: 12),
                      _MemoryCard(data: memory),
                      const SizedBox(height: 12),
                      _DisksCard(data: disks),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String? _headerSubtitle(Map<String, dynamic>? r) {
    if (r == null || r['ok'] != true) return null;
    if (_loading) return 'Refreshing…';
    if (r['cached_at_ms'] != null) return _cacheAgeLabel(r);
    return null;
  }
}

class _HardwareHeader extends StatelessWidget {
  const _HardwareHeader({
    required this.overall,
    required this.loading,
    required this.staleLabel,
    required this.onRefresh,
  });

  final String overall;
  final bool loading;
  final String? staleLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hardware',
                style: TextStyle(
                  color: AppTheme.textPrimaryFor(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'CPU, memory, and storage health (engine may take 10–20s).',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 13,
                ),
              ),
              if (staleLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  staleLabel!,
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        _StatusPill(status: overall, big: true),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// CPU
// --------------------------------------------------------------------------- //

class _CpuCard extends StatelessWidget {
  const _CpuCard({required this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) return const _ComponentPlaceholder(label: 'CPU');
    final status = (data!['status'] as String?) ?? 'unknown';
    final m = (data!['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    final issues = (data!['issues'] as List?) ?? const [];

    final tempC = m['max_temp_c'] as num?;
    final freqCur = m['freq_current_mhz'] as num?;
    final freqMax = m['freq_max_mhz'] as num?;
    final freqRatio = m['freq_ratio'] as num?;
    final cores = m['cores_physical'] as num?;
    final logical = m['cores_logical'] as num?;
    final loadAvg = m['load_avg_pct'] as num?;
    final loadMax = m['load_max_core_pct'] as num?;

    return _ComponentCard(
      icon: Icons.developer_board,
      title: 'CPU',
      status: status,
      issues: issues,
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          _Metric(
              label: 'Cores',
              value: cores == null
                  ? '—'
                  : '${cores.toInt()}c / ${logical?.toInt() ?? '?'}t'),
          _Metric(
            label: 'Load',
            value: loadAvg == null
                ? '—'
                : '${loadAvg.toStringAsFixed(0)}% • peak ${loadMax?.toStringAsFixed(0) ?? '—'}%',
          ),
          _Metric(
            label: 'Frequency',
            value: freqCur == null
                ? '—'
                : '${(freqCur / 1000).toStringAsFixed(2)} GHz'
                    '${freqMax != null ? ' / ${(freqMax / 1000).toStringAsFixed(2)} GHz' : ''}',
          ),
          _Metric(
            label: 'Clock ratio',
            value: freqRatio == null
                ? '—'
                : '${(freqRatio * 100).toStringAsFixed(0)}%',
          ),
          _Metric(
            label: 'Temp',
            value: tempC == null
                ? 'sensor unavailable'
                : '${tempC.toStringAsFixed(1)} °C',
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Memory
// --------------------------------------------------------------------------- //

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) return const _ComponentPlaceholder(label: 'Memory');
    final status = (data!['status'] as String?) ?? 'unknown';
    final m = (data!['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    final issues = (data!['issues'] as List?) ?? const [];
    final modules = (data!['items'] as List?) ?? const [];

    return _ComponentCard(
      icon: Icons.memory,
      title: 'Memory',
      status: status,
      issues: issues,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Metric(
                label: 'Installed',
                value: _formatBytes(m['total_bytes'] as num?),
              ),
              _Metric(
                label: 'Used',
                value:
                    '${_formatBytes(m['used_bytes'] as num?)} (${(m['percent'] as num?)?.toStringAsFixed(0) ?? '—'}%)',
              ),
              _Metric(
                label: 'Available',
                value: _formatBytes(m['available_bytes'] as num?),
              ),
              _Metric(
                label: 'Swap',
                value:
                    '${(m['swap_percent'] as num?)?.toStringAsFixed(0) ?? '0'}% of ${_formatBytes(m['swap_total_bytes'] as num?)}',
              ),
            ],
          ),
          if (modules.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Modules',
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            for (final mod in modules.whereType<Map>())
              _ModuleRow(module: Map<String, dynamic>.from(mod)),
          ],
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});
  final Map<String, dynamic> module;

  @override
  Widget build(BuildContext context) {
    final slot = (module['slot'] as String?) ?? 'DIMM';
    final manufacturer = (module['manufacturer'] as String?) ?? 'Unknown';
    final part = (module['part_number'] as String?) ?? '';
    final capacity = _formatBytes(module['capacity_bytes'] as num?);
    final speed = module['speed_mhz'];
    final configured = module['configured_speed_mhz'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              slot,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$manufacturer ${part.isNotEmpty ? part : ''}'.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimaryFor(context),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            capacity,
            style: TextStyle(
              color: AppTheme.textPrimaryFor(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            speed == null
                ? '—'
                : '$speed MHz${configured != null && configured != speed ? ' @ $configured' : ''}',
            style: TextStyle(
              color: AppTheme.textMutedFor(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Disks
// --------------------------------------------------------------------------- //

class _DisksCard extends StatelessWidget {
  const _DisksCard({required this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) return const _ComponentPlaceholder(label: 'Disks');
    final status = (data!['status'] as String?) ?? 'unknown';
    final issues = (data!['issues'] as List?) ?? const [];
    final items = (data!['items'] as List?) ?? const [];

    final physical = items
        .whereType<Map>()
        .where((m) => m['kind'] == 'physical')
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final volumes = items
        .whereType<Map>()
        .where((m) => m['kind'] == 'volume')
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    return _ComponentCard(
      icon: Icons.storage,
      title: 'Storage devices',
      status: status,
      issues: issues,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (physical.isNotEmpty) ...[
            Text(
              'Physical disks',
              style: _sectionLabel(context),
            ),
            const SizedBox(height: 8),
            for (final d in physical) _PhysicalDiskRow(disk: d),
            const SizedBox(height: 16),
          ],
          if (volumes.isNotEmpty) ...[
            Text(
              'Volumes',
              style: _sectionLabel(context),
            ),
            const SizedBox(height: 8),
            for (final v in volumes) _VolumeRow(volume: v),
          ],
          if (physical.isEmpty && volumes.isEmpty)
            Text(
              'No storage devices detected.',
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _sectionLabel(BuildContext context) => TextStyle(
        color: AppTheme.textMutedFor(context),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );
}

class _PhysicalDiskRow extends StatelessWidget {
  const _PhysicalDiskRow({required this.disk});
  final Map<String, dynamic> disk;

  @override
  Widget build(BuildContext context) {
    final name = (disk['name'] as String?) ?? 'Disk';
    final media = (disk['media_type'] as String?) ?? '';
    final bus = (disk['bus_type']?.toString()) ?? '';
    final size = _formatBytes(disk['size_bytes'] as num?);
    final status = (disk['status'] as String?) ?? 'unknown';
    final smart = (disk['smart'] as Map?) ?? const {};
    final issues = (disk['issues'] as List?) ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightFor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: AppTheme.textPrimaryFor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      [
                        if (media.isNotEmpty) media,
                        if (bus.isNotEmpty) bus,
                        size,
                      ].join(' • '),
                      style: TextStyle(
                        color: AppTheme.textMutedFor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          if (smart.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _formatSmart(smart),
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
          for (final i in issues)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                i.toString(),
                style: TextStyle(
                  color: AppTheme.error,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSmart(Map smart) {
    final src = smart['source'];
    final health = smart['health_status'];
    final op = smart['operational_status'];
    final passed = smart['passed'];
    final parts = <String>[];
    if (src != null) parts.add('source: $src');
    if (health != null) parts.add('health: $health');
    if (op != null) parts.add('op: $op');
    if (passed != null) parts.add('smart_passed: $passed');
    return parts.join(' | ');
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.volume});
  final Map<String, dynamic> volume;

  @override
  Widget build(BuildContext context) {
    final mount = (volume['mountpoint'] as String?) ?? '?';
    final fs = (volume['fstype'] as String?) ?? '';
    final total = _formatBytes(volume['total_bytes'] as num?);
    final free = _formatBytes(volume['free_bytes'] as num?);
    final freePct = (volume['free_percent'] as num?)?.toDouble() ?? 0;
    final status = (volume['status'] as String?) ?? 'unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              mount,
              style: TextStyle(
                color: AppTheme.textPrimaryFor(context),
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (100 - freePct).clamp(0, 100) / 100.0,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceLightFor(context),
              valueColor: AlwaysStoppedAnimation(
                _statusColor(status, context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: Text(
              '$free free of $total ($fs)',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(status: status),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Shared widgets + helpers
// --------------------------------------------------------------------------- //

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.issues,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String status;
  final List issues;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _statusColor(status, context), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimaryFor(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 12),
            child,
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final issue in issues)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: _statusColor(status, context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          issue.toString(),
                          style: TextStyle(
                            color: AppTheme.textSecondaryFor(context),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComponentPlaceholder extends StatelessWidget {
  const _ComponentPlaceholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Waiting for $label data…',
          style: TextStyle(color: AppTheme.textMutedFor(context), fontSize: 12),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppTheme.textMutedFor(context),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimaryFor(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.big = false});
  final String status;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status, context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 14 : 10,
        vertical: big ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: big ? 12 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

Color _statusColor(String status, BuildContext context) {
  switch (status) {
    case 'healthy':
      return AppTheme.success;
    case 'warning':
      return AppTheme.warning;
    case 'critical':
      return AppTheme.error;
    default:
      return AppTheme.textMutedFor(context);
  }
}

String _formatBytes(num? raw) {
  final v = (raw ?? 0).toDouble();
  if (v <= 0) return '—';
  if (v < 1024) return '${v.toStringAsFixed(0)} B';
  if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
  if (v < 1024 * 1024 * 1024) {
    return '${(v / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(v / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
