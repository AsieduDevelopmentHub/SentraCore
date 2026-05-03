import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/sentra_panel.dart';

/// Panel displaying Root Cause Analysis for the most recent alert.
class RcaPanel extends StatelessWidget {
  const RcaPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final rca = provider.currentState?.alert.lastRootCause;

    return SentraPanel(
      title: 'Root cause analysis',
      titleIcon: Icons.troubleshoot_outlined,
      iconColor: AppTheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rca == null)
            _buildEmptyState(context)
          else ...[
            _buildAlertBanner(
              context,
              provider.currentState?.alert.lastMessage ?? '',
            ),
            const SizedBox(height: 16),
            _buildDataRow(
              context,
              'Primary bottleneck',
              rca.primaryBottleneck.toUpperCase(),
            ),
            if (rca.suspectProcess != null) ...[
              const SizedBox(height: 10),
              _buildDataRow(
                context,
                'Suspect process',
                '${rca.suspectProcess!['name']} (PID: ${rca.suspectProcess!['pid']})',
              ),
            ],
            if (rca.triggerEvent != null) ...[
              const SizedBox(height: 10),
              _buildDataRow(
                context,
                'Trigger event',
                rca.triggerEvent!['event_type'],
              ),
            ],
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
          'No recent alerts to analyze.',
          style: TextStyle(
            color: AppTheme.textMutedFor(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context, String message) {
    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: AppTheme.error, width: 3),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: AppTheme.textSecondaryFor(context),
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textMutedFor(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimaryFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
