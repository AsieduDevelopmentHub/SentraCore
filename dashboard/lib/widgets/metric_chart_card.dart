import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Real-time line chart card for a system metric.
class MetricChartCard extends StatelessWidget {
  final String title;
  final List<double> data;
  final Color color;
  final double maxY;
  final String suffix;

  const MetricChartCard({
    super.key,
    required this.title,
    required this.data,
    required this.color,
    this.maxY = 100,
    this.suffix = '%',
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = data.isNotEmpty ? data.last : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${currentValue.toStringAsFixed(1)}$suffix',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Chart
            Expanded(
              child: data.length < 2
                  ? Center(
                      child: Text(
                        'Collecting data...',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 4,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppTheme.border.withValues(alpha: 0.5),
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        clipData: const FlClipData.all(),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _buildSpots(),
                            isCurved: true,
                            curveSmoothness: 0.3,
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
                                  color.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 150),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    return List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].clamp(0, maxY)),
    );
  }
}
