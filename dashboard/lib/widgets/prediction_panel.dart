import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Panel displaying predictive forecasting and time-to-exhaustion.
class PredictionPanel extends StatelessWidget {
  const PredictionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final prediction = provider.prediction;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.online_prediction, size: 18, color: AppTheme.info),
                const SizedBox(width: 8),
                Text(
                  'Prediction & Forecasting',
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: Theme.of(context).dividerColor),
            if (prediction == null)
              _buildEmptyState(context)
            else ...[
              _buildRiskScore(context, prediction.riskScore),
              const SizedBox(height: 16),
              _buildEtaRow(
                context,
                'Memory Exhaustion',
                prediction.memoryExhaustionEtaSec,
                Icons.memory,
              ),
              const SizedBox(height: 8),
              _buildEtaRow(
                context,
                'CPU Saturation',
                prediction.cpuCriticalEtaSec,
                Icons.speed,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Waiting for trend data...',
          style: TextStyle(color: AppTheme.textMutedFor(context)),
        ),
      ),
    );
  }

  Widget _buildRiskScore(BuildContext context, double score) {
    Color color = AppTheme.stressLow;
    if (score > 60) {
      color = AppTheme.stressCritical;
    } else if (score > 30) {
      color = AppTheme.stressModerate;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Degradation Risk',
                style: TextStyle(
                    color: AppTheme.textSecondaryFor(context), fontSize: 12)),
            Text('${score.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor:
                Theme.of(context).dividerColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildEtaRow(
      BuildContext context, String label, double? etaSec, IconData icon) {
    String text = 'Stable';
    Color color = AppTheme.textMutedFor(context);

    if (etaSec != null) {
      if (etaSec < 60) {
        text = '${etaSec.toStringAsFixed(0)}s';
        color = AppTheme.error;
      } else {
        final mins = (etaSec / 60).toStringAsFixed(1);
        text = '${mins}m';
        color = AppTheme.warning;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightFor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryFor(context)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: AppTheme.textSecondaryFor(context), fontSize: 13)),
          const Spacer(),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
