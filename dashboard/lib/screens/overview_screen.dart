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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
              'CPU Slope',
              trend != null
                  ? '${trend.cpuSlope > 0 ? '+' : ''}${trend.cpuSlope.toStringAsFixed(3)}%/s'
                  : '--',
              AppTheme.primary),
          _StatDivider(),
          _Stat(
              'Mem Slope',
              trend != null
                  ? '${trend.memorySlope > 0 ? '+' : ''}${trend.memorySlope.toStringAsFixed(3)}%/s'
                  : '--',
              AppTheme.accent),
          _StatDivider(),
          _Stat('Anomaly', anomaly?.level.toUpperCase() ?? '--', AppTheme.info),
          _StatDivider(),
          _Stat(
              'Alerts Fired',
              '${provider.currentState?.alert.totalFired ?? 0}',
              AppTheme.warning),
          _StatDivider(),
          _Stat(
              'Baseline',
              provider.engineInfo?.baselineReady == true ? 'READY' : 'LEARNING',
              provider.engineInfo?.baselineReady == true
                  ? AppTheme.accent
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
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppTheme.border);
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          const Spacer(),
          if (provider.engineInfo != null) ...[
            _HeaderChip(Icons.timer_outlined,
                'v${provider.engineInfo!.version}', AppTheme.info),
            const SizedBox(width: 8),
            _HeaderChip(
                Icons.data_usage,
                '${provider.engineInfo!.uptimeSamples} samples',
                AppTheme.textSecondary),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
