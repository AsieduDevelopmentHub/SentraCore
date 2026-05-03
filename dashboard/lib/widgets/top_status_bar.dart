import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

class TopStatusBar extends StatelessWidget {
  const TopStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final state = provider.currentState;
    final stability = provider.stability;
    final risk = state?.prediction.riskScore;
    final trend = state?.trend;

    final stabilityState = (stability?.state ?? 'unknown').toLowerCase();
    final stateLabel = switch (stabilityState) {
      'stable' => 'Stable',
      'degraded' => 'Warning',
      'critical' => 'Critical',
      _ => provider.connected ? 'Initializing' : 'Disconnected',
    };

    final stateColor = provider.connected
        ? AppTheme.stabilityColor(stabilityState)
        : AppTheme.critical;

    final primaryPressure = _primaryPressureLabel(provider);

    final slope = _maxAbsSlope(trend?.cpuSlope, trend?.memorySlope);
    final trendIcon = slope == null
        ? Icons.remove_rounded
        : slope > 0
            ? Icons.trending_up_rounded
            : slope < 0
                ? Icons.trending_down_rounded
                : Icons.remove_rounded;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          _StatePill(label: stateLabel, color: stateColor),
          const SizedBox(width: 14),
          _KeyStat(
            label: 'Risk',
            value: risk == null ? '--' : '${risk.toStringAsFixed(0)}%',
            color: AppTheme.primary,
          ),
          const SizedBox(width: 14),
          _KeyStat(
            label: 'Primary pressure',
            value: primaryPressure,
            color: AppTheme.accent,
          ),
          const SizedBox(width: 14),
          _KeyStat(
            label: 'Trend',
            value: _trendLabel(slope),
            color: AppTheme.textSecondaryFor(context),
            icon: trendIcon,
          ),
          const Spacer(),
          _RightMeta(provider: provider),
        ],
      ),
    );
  }

  String _primaryPressureLabel(EngineProvider provider) {
    final n = provider.normalized;
    if (n == null) return '--';
    final cpu = n.cpu.smoothed;
    final mem = n.memory.smoothed;
    final disk = n.diskIo.totalOpsPerSec;

    // Disk is not a percent; normalize against configured "spike threshold" feel.
    final diskPct = (disk / 500.0 * 100.0).clamp(0, 100).toDouble();

    final max = [cpu, mem, diskPct].reduce((a, b) => a > b ? a : b);
    if (max == cpu) return 'CPU';
    if (max == mem) return 'Memory';
    return 'Disk';
  }

  double? _maxAbsSlope(double? cpu, double? mem) {
    if (cpu == null && mem == null) return null;
    final a = cpu ?? 0;
    final b = mem ?? 0;
    return a.abs() >= b.abs() ? a : b;
  }

  String _trendLabel(double? slope) {
    if (slope == null) return '--';
    if (slope.abs() < 0.001) return 'Flat';
    return slope > 0 ? 'Rising' : 'Falling';
  }
}

class _StatePill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _KeyStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  const _KeyStat({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.textMutedFor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RightMeta extends StatelessWidget {
  final EngineProvider provider;
  const _RightMeta({required this.provider});

  @override
  Widget build(BuildContext context) {
    final engine = provider.engineInfo;
    final muted = AppTheme.textMutedFor(context);
    return Row(
      children: [
        Icon(
          provider.connected ? Icons.cloud_done_outlined : Icons.cloud_off,
          size: 18,
          color: provider.connected ? AppTheme.accent : AppTheme.critical,
        ),
        const SizedBox(width: 8),
        if (engine != null) ...[
          Text(
            'v${engine.version} • ${engine.uptimeSamples} samples',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            engine.baselineReady ? 'Baseline ready' : 'Baseline learning',
            style: TextStyle(
              color: engine.baselineReady ? AppTheme.stable : AppTheme.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          Text('Engine', style: TextStyle(color: muted, fontSize: 12)),
        ],
      ],
    );
  }
}

