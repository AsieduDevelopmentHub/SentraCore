import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/services/hardware_health_cache.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Hardware health (CPU / RAM / disks). Engine probes can take 10–20s; we
/// show the last successful snapshot from disk immediately, then refresh.
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
                      _ComponentCard(
                        title: 'CPU',
                        icon: Icons.developer_board,
                        data: components?['cpu'] as Map<String, dynamic>?,
                      ),
                      const SizedBox(height: 12),
                      _ComponentCard(
                        title: 'Memory',
                        icon: Icons.memory,
                        data: components?['memory'] as Map<String, dynamic>?,
                      ),
                      const SizedBox(height: 12),
                      _ComponentCard(
                        title: 'Storage',
                        icon: Icons.storage,
                        data: components?['disks'] as Map<String, dynamic>?,
                        isDisk: true,
                      ),
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
        _StatusPill(status: overall),
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

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.title,
    required this.icon,
    required this.data,
    this.isDisk = false,
  });

  final String title;
  final IconData icon;
  final Map<String, dynamic>? data;
  final bool isDisk;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$title: no data',
            style: TextStyle(color: AppTheme.textMutedFor(context)),
          ),
        ),
      );
    }
    final d = data!;
    final status = (d['status'] as String?) ?? 'unknown';
    final metrics = (d['metrics'] as Map?)?.cast<String, dynamic>() ?? {};
    final issues = (d['issues'] as List?) ?? const [];
    final items = (d['items'] as List?) ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _statusColor(status, context)),
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
            const SizedBox(height: 8),
            if (metrics.isNotEmpty)
              Text(
                metrics.entries
                    .where((e) => e.value != null)
                    .map((e) => '${e.key}: ${e.value}')
                    .take(8)
                    .join(' • '),
                style: TextStyle(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 11,
                ),
              ),
            if (isDisk && items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...items.take(6).map((raw) {
                if (raw is! Map) return const SizedBox.shrink();
                final m = Map<String, dynamic>.from(raw);
                final kind = m['kind'] ?? '';
                final line = kind == 'volume'
                    ? '${m['mountpoint'] ?? ''} ${m['free_percent'] ?? ''}% free'
                    : '${m['name'] ?? 'Disk'} (${m['media_type'] ?? ''})';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: TextStyle(
                      color: AppTheme.textMutedFor(context),
                      fontSize: 11,
                    ),
                  ),
                );
              }),
            ],
            for (final i in issues)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  i.toString(),
                  style: TextStyle(color: AppTheme.error, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
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
