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
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();

    return Column(
      children: [
        _OverviewChrome(
          provider: provider,
          controller: _searchController,
          onQueryChanged: (v) => setState(() => _query = v),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveRowColumn(
                  spacing: 14,
                  children: [
                    const SizedBox(width: 220, child: StabilityIndicator()),
                    Expanded(
                      child: Column(
                        children: [
                          ResponsiveRowColumn(
                            spacing: 14,
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
                          const SizedBox(height: 14),
                          _StatsStrip(provider: provider),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const ResponsiveRowColumn(
                  spacing: 14,
                  children: [
                    Expanded(child: PredictionPanel()),
                    Expanded(child: RcaPanel()),
                  ],
                ),
                const SizedBox(height: 18),
                ResponsiveRowColumn(
                  spacing: 14,
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
                const SizedBox(height: 18),
                ResponsiveRowColumn(
                  spacing: 14,
                  useIntrinsicHeight: false,
                  children: [
                    Expanded(
                        flex: 3,
                        child: SizedBox(
                            height: 300, child: ProcessTable(filter: _query))),
                    Expanded(
                        flex: 2,
                        child: SizedBox(
                            height: 300, child: EventTimeline(filter: _query))),
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
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  const _OverviewChrome({
    required this.provider,
    required this.controller,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 980;

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
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: controller,
                              onChanged: onQueryChanged,
                              style: TextStyle(
                                color: AppTheme.textPrimaryFor(context),
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search processes, events…',
                                prefixIcon:
                                    const Icon(Icons.search_rounded, size: 18),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (!compact && provider.engineInfo != null) ...[
                              _HeaderChip(
                                icon: Icons.tag_outlined,
                                label: 'v${provider.engineInfo!.version}',
                                color: AppTheme.primary,
                              ),
                              _HeaderChip(
                                icon: Icons.timeline_outlined,
                                label:
                                    '${provider.engineInfo!.uptimeSamples} samples',
                                color: AppTheme.accent,
                              ),
                            ],
                            SizedBox(
                              width: compact ? 44 : null,
                              child: _LiveConnectionPill(
                                  connected: provider.connected),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      AppTheme.surfaceLightFor(context).withValues(alpha: 0.55),
                  border: Border(
                    top: BorderSide(color: divider.withValues(alpha: 0.65)),
                  ),
                ),
                child: _IntelStrip(provider: provider),
              ),
            ],
          ),
        );
      },
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
      final s => s.abs() < 0.001 ? 'Flat' : (s > 0 ? 'Rising' : 'Falling'),
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
              _IntelKV('State', stateLabel,
                  valueColor: stateColor, emphasize: true),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 118;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: 8,
          ),
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
              if (!compact) ...[
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
            ],
          ),
        );
      },
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

    return LayoutBuilder(
      builder: (context, c) {
        final tiles = [
          _StatTile(
            label: 'CPU slope',
            value: trend != null
                ? '${trend.cpuSlope > 0 ? '+' : ''}${trend.cpuSlope.toStringAsFixed(3)}%/s'
                : '—',
            valueColor: AppTheme.primary,
          ),
          _StatTile(
            label: 'Memory slope',
            value: trend != null
                ? '${trend.memorySlope > 0 ? '+' : ''}${trend.memorySlope.toStringAsFixed(3)}%/s'
                : '—',
            valueColor: AppTheme.accent,
          ),
          _StatTile(
            label: 'Anomaly',
            value: anomaly?.level.toUpperCase() ?? '—',
            valueColor: AppTheme.info,
          ),
          _StatTile(
            label: 'Alerts',
            value: '${provider.currentState?.alert.totalFired ?? 0}',
            valueColor: AppTheme.warning,
          ),
          _StatTile(
            label: 'Baseline',
            value: provider.engineInfo?.baselineReady == true
                ? 'READY'
                : 'LEARNING',
            valueColor: provider.engineInfo?.baselineReady == true
                ? AppTheme.success
                : AppTheme.textMutedFor(context),
          ),
        ];

        // Aim for 3 + 2 on typical widths.
        final itemWidth = c.maxWidth >= 900 ? 210.0 : 180.0;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final t in tiles) SizedBox(width: itemWidth, child: t),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _StatDivider removed (stats strip now uses Wrap/Expanded layout).
