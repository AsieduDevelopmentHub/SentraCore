import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Status bar in the app bar showing connection state, baseline progress, and uptime.
class EngineStatusBar extends StatelessWidget {
  const EngineStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final engine = provider.engineInfo;
    final connected = provider.connected;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baseline status
          if (engine != null) ...[
            _StatusChip(
              icon: Icons.school_outlined,
              label: engine.baselineReady
                  ? 'Baseline Ready'
                  : 'Learning (${engine.baselineSamples}/60)',
              color: engine.baselineReady ? AppTheme.accent : AppTheme.warning,
            ),
            const SizedBox(width: 8),
          ],

          // Alert count
          if (provider.currentState != null) ...[
            _StatusChip(
              icon: Icons.notifications_none,
              label: '${provider.currentState!.alert.totalFired}',
              color: provider.currentState!.alert.totalFired > 0
                  ? AppTheme.error
                  : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
          ],

          // Connection indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connected ? AppTheme.accent : AppTheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (connected ? AppTheme.accent : AppTheme.error)
                      .withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              fontSize: 11,
              color: connected ? AppTheme.accent : AppTheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
