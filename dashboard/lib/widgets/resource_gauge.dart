import 'package:flutter/material.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Resource gauge card showing current utilization with spike indicator.
class ResourceGauge extends StatelessWidget {
  final String label;
  final double value;
  final bool isSpiking;
  final Color color;
  final IconData icon;
  final String suffix;
  final double? rawValue;

  const ResourceGauge({
    super.key,
    required this.label,
    required this.value,
    required this.isSpiking,
    required this.color,
    required this.icon,
    this.suffix = '%',
    this.rawValue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isSpiking)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SPIKE',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rawValue != null
                      ? rawValue!.toStringAsFixed(0)
                      : value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMutedFor(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0, 1),
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSpiking ? AppTheme.error : color,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
