import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/connection_banner.dart';
import 'package:sentracore_dashboard/widgets/engine_status_bar.dart';
import 'package:sentracore_dashboard/widgets/event_timeline.dart';
import 'package:sentracore_dashboard/widgets/metric_chart_card.dart';
import 'package:sentracore_dashboard/widgets/process_table.dart';
import 'package:sentracore_dashboard/widgets/resource_gauge.dart';
import 'package:sentracore_dashboard/widgets/stability_indicator.dart';
import 'package:sentracore_dashboard/widgets/prediction_panel.dart';
import 'package:sentracore_dashboard/widgets/rca_panel.dart';

/// Main dashboard screen — real-time system intelligence overview.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('SentraCore'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'v0.1.0',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: const [EngineStatusBar()],
      ),
      body: const _DashboardBody(),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();

    return Column(
      children: [
        // Connection banner
        if (!provider.connected) const ConnectionBanner(),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Stress indicator + resource gauges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stability score — big, prominent
                    const Expanded(flex: 2, child: StabilityIndicator()),
                    const SizedBox(width: 16),

                    // Resource gauges
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: ResourceGauge(
                              label: 'CPU',
                              value: provider.normalized?.cpu.smoothed ?? 0,
                              isSpiking: provider.normalized?.cpu.spiking ?? false,
                              color: AppTheme.primary,
                              icon: Icons.memory,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ResourceGauge(
                              label: 'Memory',
                              value: provider.normalized?.memory.smoothed ?? 0,
                              isSpiking: provider.normalized?.memory.spiking ?? false,
                              color: AppTheme.accent,
                              icon: Icons.storage,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ResourceGauge(
                              label: 'Disk I/O',
                              value: _diskPercent(provider),
                              isSpiking: provider.normalized?.diskIo.spiking ?? false,
                              color: AppTheme.warning,
                              icon: Icons.disc_full_outlined,
                              suffix: 'ops/s',
                              rawValue: provider.normalized?.diskIo.totalOpsPerSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Row 2: Intelligence Panels (Prediction & RCA)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(child: PredictionPanel()),
                    SizedBox(width: 16),
                    Expanded(child: RcaPanel()),
                  ],
                ),

                const SizedBox(height: 16),

                // Row 3: Charts
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricChartCard(
                          title: 'CPU Usage',
                          data: provider.cpuHistory,
                          color: AppTheme.primary,
                          maxY: 100,
                          suffix: '%',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricChartCard(
                          title: 'Memory Usage',
                          data: provider.memoryHistory,
                          color: AppTheme.accent,
                          maxY: 100,
                          suffix: '%',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricChartCard(
                          title: 'Stability Index',
                          data: provider.stabilityHistory,
                          color: AppTheme.stressLow,
                          maxY: 100,
                          suffix: '',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Row 4: Process table + event timeline
                SizedBox(
                  height: 320,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(flex: 3, child: ProcessTable()),
                      SizedBox(width: 16),
                      Expanded(flex: 2, child: EventTimeline()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _diskPercent(EngineProvider provider) {
    final ops = provider.normalized?.diskIo.totalOpsPerSec ?? 0;
    // Normalize to 0-100 range (500 ops/sec = 100%)
    return (ops / 500 * 100).clamp(0, 100);
  }
}
