import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/stability_indicator.dart';
import 'package:sentracore_dashboard/widgets/detailed_resource_gauge.dart';
import 'package:sentracore_dashboard/widgets/prediction_panel.dart';
import 'package:sentracore_dashboard/widgets/rca_panel.dart';
import 'package:sentracore_dashboard/widgets/metric_chart_card.dart';
import 'package:sentracore_dashboard/widgets/process_table.dart';
import 'package:sentracore_dashboard/widgets/event_timeline.dart';
import 'package:sentracore_dashboard/widgets/responsive_builder.dart';

/// Screen 1: At-a-glance overview of current system health.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();

    return Column(
      children: [
        _OverviewChrome(provider: provider),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveRowColumn(
                  spacing: 12,
                  children: [
                    const SizedBox(width: 220, child: StabilityIndicator()),
                    Expanded(
                      child: Column(
                        children: [
                          ResponsiveRowColumn(
                            spacing: 12,
                            useIntrinsicHeight: false,
                            children: [
                              Expanded(
                                child: DetailedResourceGauge(
                                  label: 'CPU',
                                  value: provider.normalized?.cpu.smoothed ?? 0,
                                  isSpiking:
                                      provider.normalized?.cpu.spiking ?? false,
                                  color: AppTheme.primary,
                                  icon: Icons.memory,
                                  subtitle: 'Smoothed EMA',
                                ),
                              ),
                              Expanded(
                                child: DetailedResourceGauge(
                                  label: 'Memory',
                                  value:
                                      provider.normalized?.memory.smoothed ?? 0,
                                  isSpiking:
                                      provider.normalized?.memory.spiking ??
                                          false,
                                  color: AppTheme.accent,
                                  icon: Icons.storage,
                                  subtitle:
                                      '${((provider.normalized?.memory.used ?? 0) / 1024 / 1024 / 1024).toStringAsFixed(1)} GB used',
                                ),
                              ),
                              Expanded(
                                child: DetailedResourceGauge(
                                  label: 'Disk Activity',
                                  value: _diskPercent(provider),
                                  isSpiking:
                                      provider.normalized?.diskIo.spiking ??
                                          false,
                                  color: AppTheme.warning,
                                  icon: Icons.disc_full_outlined,
                                  subtitle:
                                      '${provider.normalized?.diskIo.totalOpsPerSec.toStringAsFixed(0) ?? 0} ops/s',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _StatsStrip(provider: provider),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ResponsiveRowColumn(
                  spacing: 12,
                  children: [
                    Expanded(child: PredictionPanel()),
                    Expanded(child: RcaPanel()),
                  ],
                ),
                const SizedBox(height: 16),
                ResponsiveRowColumn(
                  spacing: 12,
                  useIntrinsicHeight: false,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 180,
                        child: MetricChartCard(
                          title: 'CPU History',
                          data: provider.cpuHistory,
                          color: AppTheme.primary,
                          maxY: 100,
                          suffix: '%',
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 180,
                        child: MetricChartCard(
                          title: 'Memory History',
                          data: provider.memoryHistory,
                          color: AppTheme.accent,
                          maxY: 100,
                          suffix: '%',
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 180,
                        child: MetricChartCard(
                          title: 'Stability History',
                          data: provider.stabilityHistory,
                          color: AppTheme.stressLow,
                          maxY: 100,
                          suffix: '',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ResponsiveRowColumn(
                  spacing: 12,
                  useIntrinsicHeight: false,
                  children: [
                    Expanded(
                        flex: 3,
                        child: SizedBox(height: 300, child: ProcessTable())),
                    Expanded(
                        flex: 2,
                        child: SizedBox(height: 300, child: EventTimeline())),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _diskPercent(EngineProvider p) =>
      ((p.normalized?.diskIo.totalOpsPerSec ?? 0) / 500 * 100).clamp(0, 100);
}

/// Primary overview chrome: title row (search, engine meta) + intelligence strip.
class _OverviewChrome extends StatelessWidget {
  final EngineProvider provider;
  const _OverviewChrome({required this.provider});

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System overview',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time health, risk, and intelligence summary',
                      style: TextStyle(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLightFor(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: divider.withValues(alpha: 0.9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: AppTheme.textMutedFor(context),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Search processes, events…',
                              style: TextStyle(
                                color: AppTheme.textMutedFor(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                if (provider.engineInfo != null) ...[
                  _HeaderChip(
                    icon: Icons.tag_outlined,
                    label: 'v${provider.engineInfo!.version}',
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  _HeaderChip(
                    icon: Icons.timeline_outlined,
                    label:
                        '${provider.engineInfo!.uptimeSamples.toString()} samples',
                    color: AppTheme.accent,
                  ),
                ],
                const SizedBox(width: 16),
                _LiveConnectionPill(connected: provider.connected),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLightFor(context).withValues(alpha: 0.55),
              border: Border(
                top: BorderSide(color: divider.withValues(alpha: 0.65)),
              ),
            ),
            child: _IntelStrip(provider: provider),
          ),
        ],
      ),
    );
  }
}

class _IntelStrip extends StatelessWidget {
  final EngineProvider provider;
  const _IntelStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final stability = provider.stability;
    final state = provider.currentState;
    final risk = state?.prediction?.riskScore;
    final trend = state?.trend;
    final stabilityState = (stability?.state ?? 'unknown').toLowerCase();

    final stateLabel = switch (stabilityState) {
      'stable' => 'Stable',
      'degraded' => 'Degrading',
      'critical' => 'Critical',
      _ => provider.connected ? 'Initializing' : 'Disconnected',
    };

    final stateColor = provider.connected
        ? AppTheme.stabilityColor(stabilityState)
        : AppTheme.critical;

    final slope = _maxAbsSlope(trend?.cpuSlope, trend?.memorySlope);
    final trendText = switch (slope) {
      null => '—',
      final s =>
        s.abs() < 0.001 ? 'Flat' : (s > 0 ? 'Rising' : 'Falling'),
    };

    final pressure = _primaryPressureLabel(provider);

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        if (narrow) {
          return Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _IntelKV(
                  'State', stateLabel, valueColor: stateColor, emphasize: true),
              _IntelKV(
                'Stability',
                stability != null ? stability.score.toStringAsFixed(0) : '—',
              ),
              _IntelKV(
                'Risk',
                risk == null ? '—' : '${risk.toStringAsFixed(0)}%',
              ),
              _IntelKV('Load', pressure),
              _IntelKV('Trend', trendText),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _IntelKV('State', stateLabel,
                  valueColor: stateColor, emphasize: true),
            ),
            const _StripDivider(),
            Expanded(
              child: _IntelKV(
                'Stability index',
                stability != null ? stability.score.toStringAsFixed(0) : '—',
              ),
            ),
            const _StripDivider(),
            Expanded(
              child: _IntelKV(
                'Degradation risk',
                risk == null ? '—' : '${risk.toStringAsFixed(0)}%',
              ),
            ),
            const _StripDivider(),
            Expanded(child: _IntelKV('Primary pressure', pressure)),
            const _StripDivider(),
            Expanded(child: _IntelKV('Resource trend', trendText)),
          ],
        );
      },
    );
  }

  String _primaryPressureLabel(EngineProvider p) {
    final n = p.normalized;
    if (n == null) return '—';
    final cpu = n.cpu.smoothed;
    final mem = n.memory.smoothed;
    final diskPct =
        (n.diskIo.totalOpsPerSec / 500.0 * 100.0).clamp(0, 100).toDouble();
    final max = [cpu, mem, diskPct].reduce((a, b) => a > b ? a : b);
    if (max == cpu) return 'CPU';
    if (max == mem) return 'Memory';
    return 'Disk I/O';
  }

  double? _maxAbsSlope(double? cpu, double? mem) {
    if (cpu == null && mem == null) return null;
    final a = cpu ?? 0;
    final b = mem ?? 0;
    return a.abs() >= b.abs() ? a : b;
  }
}

class _IntelKV extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  const _IntelKV(
    this.label,
    this.value, {
    this.valueColor,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppTheme.textMutedFor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 15 : 14,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
            color: valueColor ?? AppTheme.textPrimaryFor(context),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _StripDivider extends StatelessWidget {
  const _StripDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveConnectionPill extends StatelessWidget {
  final bool connected;
  const _LiveConnectionPill({required this.connected});

  @override
  Widget build(BuildContext context) {
    final c = connected ? AppTheme.stable : AppTheme.critical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? 'Engine live' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final EngineProvider provider;
  const _StatsStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final trend = provider.currentState?.trend;
    final anomaly = provider.currentState?.anomaly;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(
              'CPU slope',
              trend != null
                  ? '${trend.cpuSlope > 0 ? '+' : ''}${trend.cpuSlope.toStringAsFixed(3)}%/s'
                  : '—',
              AppTheme.primary),
          _StatDivider(),
          _Stat(
              'Memory slope',
              trend != null
                  ? '${trend.memorySlope > 0 ? '+' : ''}${trend.memorySlope.toStringAsFixed(3)}%/s'
                  : '—',
              AppTheme.accent),
          _StatDivider(),
          _Stat('Anomaly', anomaly?.level.toUpperCase() ?? '—', AppTheme.info),
          _StatDivider(),
          _Stat('Alerts', '${provider.currentState?.alert.totalFired ?? 0}',
              AppTheme.warning),
          _StatDivider(),
          _Stat(
              'Baseline',
              provider.engineInfo?.baselineReady == true ? 'Ready' : 'Learning',
              provider.engineInfo?.baselineReady == true
                  ? AppTheme.success
                  : AppTheme.textMutedFor(context)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMutedFor(context),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 24,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
      );
}
