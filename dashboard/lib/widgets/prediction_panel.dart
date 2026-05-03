import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/sentra_panel.dart';

/// Panel displaying predictive forecasting and time-to-exhaustion.
class PredictionPanel extends StatelessWidget {
  const PredictionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final prediction = provider.prediction;

    return SentraPanel(
      title: 'Prediction & forecasting',
      titleIcon: Icons.online_prediction_outlined,
      iconColor: AppTheme.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prediction == null)
            _buildEmptyState(context)
          else ...[
            _buildRiskScore(context, prediction.riskScore),
            const SizedBox(height: 16),
            _buildEtaRow(
              context,
              'Memory exhaustion',
              prediction.memoryExhaustionEtaSec,
              Icons.memory_outlined,
            ),
            const SizedBox(height: 8),
            _buildEtaRow(
              context,
              'CPU saturation',
              prediction.cpuCriticalEtaSec,
              Icons.speed_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'Waiting for trend data…',
          style: TextStyle(
            color: AppTheme.textMutedFor(context),
            fontSize: 13,
          ),
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
            Text(
              'Degradation risk',
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
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
    BuildContext context,
    String label,
    double? etaSec,
    IconData icon,
  ) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightFor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.85),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondaryFor(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
