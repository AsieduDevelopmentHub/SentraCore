import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/responsive_builder.dart';

/// Screen 2: Full-page detailed performance charts.
class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();

    return Column(
      children: [
        _PerformanceHeader(provider: provider),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // CPU + Memory full charts
                ResponsiveRowColumn(
                  spacing: 12,
                  useIntrinsicHeight: false,
                  children: [
                    Expanded(
                      child: _DetailedChart(
                        title: 'CPU Usage',
                        data: provider.cpuHistory,
                        color: AppTheme.primary,
                        unit: '%',
                        thresholdY: 90,
                        thresholdLabel: 'Critical',
                        stats: _chartStats(provider.cpuHistory, '%'),
                      ),
                    ),
                    Expanded(
                      child: _DetailedChart(
                        title: 'Memory Usage',
                        data: provider.memoryHistory,
                        color: AppTheme.accent,
                        unit: '%',
                        thresholdY: 90,
                        thresholdLabel: 'High',
                        stats: _chartStats(provider.memoryHistory, '%'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Disk + Stability full charts
                ResponsiveRowColumn(
                  spacing: 12,
                  useIntrinsicHeight: false,
                  children: [
                    Expanded(
                      child: _DetailedChart(
                        title: 'Disk I/O',
                        data: provider.diskHistory,
                        color: AppTheme.warning,
                        unit: ' ops/s',
                        maxY: 500,
                        stats: _chartStats(provider.diskHistory, ' ops/s',
                            maxVal: 500),
                      ),
                    ),
                    Expanded(
                      child: _DetailedChart(
                        title: 'System Stability Index',
                        data: provider.stabilityHistory,
                        color: AppTheme.stressLow,
                        unit: '',
                        invertColors: true,
                        stats: _chartStats(provider.stabilityHistory, ''),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Trend & anomaly info row
                ResponsiveRowColumn(
                  spacing: 12,
                  children: [
                    Expanded(child: _TrendCard(provider: provider)),
                    Expanded(child: _AnomalyCard(provider: provider)),
                    Expanded(child: _StressCard(provider: provider)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, String> _chartStats(List<double> data, String unit,
      {double maxVal = 100}) {
    if (data.isEmpty) {
      return {'min': '--', 'max': '--', 'avg': '--', 'cur': '--'};
    }
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final avg = data.reduce((a, b) => a + b) / data.length;
    return {
      'min': '${min.toStringAsFixed(1)}$unit',
      'max': '${max.toStringAsFixed(1)}$unit',
      'avg': '${avg.toStringAsFixed(1)}$unit',
      'cur': '${data.last.toStringAsFixed(1)}$unit',
    };
  }
}

class _PerformanceHeader extends StatelessWidget {
  final EngineProvider provider;
  const _PerformanceHeader({required this.provider});

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
              Text('Performance',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text('60-second rolling history with trend analysis',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.circle, size: 6, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text('Live — 2s interval',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DetailedChart extends StatelessWidget {
  final String title;
  final List<double> data;
  final Color color;
  final String unit;
  final double maxY;
  final double? thresholdY;
  final String? thresholdLabel;
  final Map<String, String> stats;
  final bool invertColors;

  const _DetailedChart({
    required this.title,
    required this.data,
    required this.color,
    required this.unit,
    this.maxY = 100,
    this.thresholdY,
    this.thresholdLabel,
    required this.stats,
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = data.isNotEmpty ? data.last : 0.0;
    Color valueColor = color;
    if (thresholdY != null && currentValue >= thresholdY!) {
      valueColor = AppTheme.error;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${currentValue.toStringAsFixed(1)}$unit',
                  style: TextStyle(
                      color: valueColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chart
            SizedBox(
              height: 200,
              child: data.length < 2
                  ? Center(
                      child: Text('Collecting data...',
                          style: TextStyle(color: AppTheme.textMuted)))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 5,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: AppTheme.border.withValues(alpha: 0.5),
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) => Text(
                                v.toStringAsFixed(0),
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 9),
                              ),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                              bottom: BorderSide(
                                  color:
                                      AppTheme.border.withValues(alpha: 0.5))),
                        ),
                        clipData: const FlClipData.all(),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots
                                .map((s) => LineTooltipItem(
                                      '${s.y.toStringAsFixed(1)}$unit',
                                      TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ))
                                .toList(),
                          ),
                        ),
                        extraLinesData: thresholdY != null
                            ? ExtraLinesData(horizontalLines: [
                                HorizontalLine(
                                  y: thresholdY!,
                                  color: AppTheme.error.withValues(alpha: 0.5),
                                  strokeWidth: 1,
                                  dashArray: [4, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    labelResolver: (_) => thresholdLabel ?? '',
                                    style: TextStyle(
                                        color: AppTheme.error, fontSize: 9),
                                  ),
                                ),
                              ])
                            : null,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                                data.length,
                                (i) => FlSpot(
                                    i.toDouble(), data[i].clamp(0, maxY))),
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: color,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  color.withValues(alpha: 0.2),
                                  color.withValues(alpha: 0.0)
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 100),
                    ),
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: stats.entries
                  .map((e) => _MiniStat(e.key.toUpperCase(), e.value, color))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              color: AppTheme.textMuted, fontSize: 9, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _TrendCard extends StatelessWidget {
  final EngineProvider provider;
  const _TrendCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final trend = provider.currentState?.trend;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.trending_up, size: 15, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Trend Analysis',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
            const Divider(color: AppTheme.border, height: 20),
            if (trend == null)
              Text('No data', style: TextStyle(color: AppTheme.textMuted))
            else ...[
              _TrendRow('CPU Slope', trend.cpuSlope, '%/s'),
              const SizedBox(height: 8),
              _TrendRow('Memory Slope', trend.memorySlope, '%/s'),
              const SizedBox(height: 8),
              _MetricBar(
                  'CPU Volatility', trend.cpuVolatility, 20, AppTheme.primary),
              const SizedBox(height: 6),
              _MetricBar('Mem Volatility', trend.memoryVolatility, 20,
                  AppTheme.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  const _TrendRow(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    final isPositive = value > 0;
    final color = isPositive ? AppTheme.error : AppTheme.accent;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Row(children: [
          Icon(isPositive ? Icons.trending_up : Icons.trending_down,
              size: 13, color: color),
          const SizedBox(width: 4),
          Text('${isPositive ? '+' : ''}${value.toStringAsFixed(4)}$unit',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  const _MetricBar(this.label, this.value, this.maxValue, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        Text(value.toStringAsFixed(2),
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (value / maxValue).clamp(0, 1),
          backgroundColor: AppTheme.surfaceLight,
          valueColor:
              AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.7)),
          minHeight: 4,
        ),
      ),
    ]);
  }
}

class _AnomalyCard extends StatelessWidget {
  final EngineProvider provider;
  const _AnomalyCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final anomaly = provider.currentState?.anomaly;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.radar, size: 15, color: AppTheme.info),
              const SizedBox(width: 6),
              Text('Anomaly Detection',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
            const Divider(color: AppTheme.border, height: 20),
            if (anomaly == null)
              Text('No data', style: TextStyle(color: AppTheme.textMuted))
            else ...[
              _MetricBar('CPU Z-Score', anomaly.cpuZScore, 4, AppTheme.primary),
              const SizedBox(height: 8),
              _MetricBar(
                  'Memory Z-Score', anomaly.memoryZScore, 4, AppTheme.accent),
              const SizedBox(height: 8),
              _MetricBar(
                  'Disk Z-Score', anomaly.diskZScore, 4, AppTheme.warning),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Anomaly Level',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                _LevelBadge(anomaly.level),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge(this.level);

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      'normal' => AppTheme.accent,
      'elevated' => AppTheme.info,
      'high' => AppTheme.warning,
      'severe' => AppTheme.error,
      _ => AppTheme.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(level.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }
}

class _StressCard extends StatelessWidget {
  final EngineProvider provider;
  const _StressCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final stress = provider.stress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.speed, size: 15, color: AppTheme.warning),
              const SizedBox(width: 6),
              Text('Stress Engine',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
            const Divider(color: AppTheme.border, height: 20),
            if (stress == null)
              Text('No data', style: TextStyle(color: AppTheme.textMuted))
            else ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Score',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(stress.score.toStringAsFixed(1),
                    style: TextStyle(
                        color: AppTheme.stressColor(stress.level),
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              _MetricBar('CPU Pressure', (stress.pressures['cpu'] ?? 0), 100,
                  AppTheme.primary),
              const SizedBox(height: 6),
              _MetricBar('Memory Pressure', (stress.pressures['memory'] ?? 0),
                  100, AppTheme.accent),
              const SizedBox(height: 6),
              _MetricBar('Disk Pressure', (stress.pressures['disk'] ?? 0), 100,
                  AppTheme.warning),
            ],
          ],
        ),
      ),
    );
  }
}
