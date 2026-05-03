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
        _ScreenHeader(
          title: 'System Overview',
          subtitle: 'Real-time health and intelligence summary',
          provider: provider,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Stability + resource gauges
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
                          // Stats strip
                          _StatsStrip(provider: provider),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Row 2: Prediction + RCA
                ResponsiveRowColumn(
                  spacing: 12,
                  children: const [
                    Expanded(child: PredictionPanel()),
                    Expanded(child: RcaPanel()),
                  ],
                ),

                const SizedBox(height: 16),

                // Row 3: Mini charts
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

                // Row 4: Process table + events
                ResponsiveRowColumn(
                  spacing: 12,
                  useIntrinsicHeight: false,
                  children: const [
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

/// Compact stats row below gauges.
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(
              'CPU SLOPE',
              trend != null
                  ? '${trend.cpuSlope > 0 ? '+' : ''}${trend.cpuSlope.toStringAsFixed(3)}%/s'
                  : '--',
              AppTheme.primary),
          _StatDivider(),
          _Stat(
              'MEM SLOPE',
              trend != null
                  ? '${trend.memorySlope > 0 ? '+' : ''}${trend.memorySlope.toStringAsFixed(3)}%/s'
                  : '--',
              AppTheme.accent),
          _StatDivider(),
          _Stat('ANOMALY', anomaly?.level.toUpperCase() ?? '--', AppTheme.info),
          _StatDivider(),
          _Stat('ALERTS', '${provider.currentState?.alert.totalFired ?? 0}',
              AppTheme.warning),
          _StatDivider(),
          _Stat(
              'BASELINE',
              provider.engineInfo?.baselineReady == true ? 'READY' : 'LEARNING',
              provider.engineInfo?.baselineReady == true
                  ? AppTheme.success
                  : AppTheme.textMuted),
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
            color: AppTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
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
      color: Theme.of(context).dividerColor.withValues(alpha: 0.5));
}

/// Shared screen header bar.
class _ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final EngineProvider provider;
  const _ScreenHeader(
      {required this.title, required this.subtitle, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),
          // Search placeholder
          Expanded(
            child: Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Search...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (provider.engineInfo != null) ...[
            _HeaderChip(Icons.terminal_rounded,
                'v${provider.engineInfo!.version}', AppTheme.primary),
            const SizedBox(width: 12),
            _HeaderChip(
                Icons.analytics_outlined,
                '${provider.engineInfo!.uptimeSamples} SAMPLES',
                AppTheme.accent),
          ],
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person_outline_rounded,
                size: 18, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeaderChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
