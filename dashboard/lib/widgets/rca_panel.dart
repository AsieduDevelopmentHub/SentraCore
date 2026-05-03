import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Panel displaying Root Cause Analysis for the most recent alert.
class RcaPanel extends StatelessWidget {
  const RcaPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final rca = provider.currentState?.alert.lastRootCause;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Root Cause Analysis',
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: Theme.of(context).dividerColor),
            if (rca == null)
              _buildEmptyState(context)
            else ...[
              _buildAlertBanner(
                  context, provider.currentState?.alert.lastMessage ?? ''),
              const SizedBox(height: 16),
              _buildDataRow(
                  context,
                  'Primary Bottleneck:',
                  rca.primaryBottleneck.toUpperCase()),
              if (rca.suspectProcess != null) ...[
                const SizedBox(height: 8),
                _buildDataRow(
                    context,
                    'Suspect Process:',
                    '${rca.suspectProcess!['name']} (PID: ${rca.suspectProcess!['pid']})'),
              ],
              if (rca.triggerEvent != null) ...[
                const SizedBox(height: 8),
                _buildDataRow(
                    context, 'Trigger Event:', rca.triggerEvent!['event_type']),
              ],
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
          'No recent alerts to analyze.',
          style: TextStyle(color: AppTheme.textMutedFor(context)),
        ),
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context, String message) {
    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        border: Border(left: BorderSide(color: AppTheme.error, width: 4)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: AppTheme.textSecondaryFor(context),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                color: AppTheme.textPrimaryFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
