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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'SYSTEM STABILITY',
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Circular stability gauge
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10,
                      backgroundColor:
                          Theme.of(context).dividerColor.withValues(alpha: 0.1),
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
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontFamily: 'Outfit',
                          height: 1,
                        ),
                      ),
                      Text(
                        'INDEX',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // State badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text(
                state.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Divider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),

            // Penalty breakdown
            if (stability != null) ...[
              _PenaltyRow('STRESS', stability.components['stress_penalty'] ?? 0,
                  AppTheme.error),
              const SizedBox(height: 12),
              _PenaltyRow('RISK', stability.components['risk_penalty'] ?? 0,
                  AppTheme.warning),
              const SizedBox(height: 12),
              _PenaltyRow('ANOMALY',
                  stability.components['anomaly_penalty'] ?? 0, AppTheme.info),
            ],
          ],
        ),
      ),
    );
  }
}

class _PenaltyRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _PenaltyRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '-${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor:
                Theme.of(context).dividerColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
