import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Large System Stability Index gauge with penalty breakdown.
class StabilityIndicator extends StatelessWidget {
  const StabilityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final stability = provider.stability;
    final score = stability?.score ?? 100;
    final state = stability?.state ?? 'stable';
    final color = AppTheme.stabilityColor(state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'System Stability',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Circular stability gauge
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
                      backgroundColor: AppTheme.surfaceLight,
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
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // State badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                state.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Penalty breakdown
            if (stability != null) ...[
              _PenaltyBar('Stress', stability.components['stress_penalty'] ?? 0,
                  AppTheme.error),
              const SizedBox(height: 4),
              _PenaltyBar('Risk', stability.components['risk_penalty'] ?? 0,
                  AppTheme.warning),
              const SizedBox(height: 4),
              _PenaltyBar('Anomaly',
                  stability.components['anomaly_penalty'] ?? 0, AppTheme.info),
            ],
          ],
        ),
      ),
    );
  }
}

class _PenaltyBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _PenaltyBar(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100, // Show penalty size out of 100
              backgroundColor: AppTheme.surfaceLight,
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
            '-${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
