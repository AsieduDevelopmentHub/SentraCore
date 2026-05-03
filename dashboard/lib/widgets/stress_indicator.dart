import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Large stress score indicator with animated circular progress and level label.
class StressIndicator extends StatelessWidget {
  const StressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final stress = provider.stress;
    final score = stress?.score ?? 0;
    final level = stress?.level ?? 'unknown';
    final color = AppTheme.stressColor(level);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'System Stress',
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Circular stress gauge
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 8,
                      backgroundColor: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedFor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                level.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Pressure breakdown
            if (stress != null) ...[
              _PressureBar(
                  'CPU', stress.pressures['cpu'] ?? 0, AppTheme.primary),
              const SizedBox(height: 4),
              _PressureBar(
                  'Memory', stress.pressures['memory'] ?? 0, AppTheme.accent),
              const SizedBox(height: 4),
              _PressureBar(
                  'Disk', stress.pressures['disk'] ?? 0, AppTheme.warning),
            ],
          ],
        ),
      ),
    );
  }
}

class _PressureBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _PressureBar(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSecondaryFor(context)),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor:
                  Theme.of(context).dividerColor.withValues(alpha: 0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.7)),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 32,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            style:
                TextStyle(fontSize: 10, color: AppTheme.textMutedFor(context)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
