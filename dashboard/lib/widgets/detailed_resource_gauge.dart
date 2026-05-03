import 'package:flutter/material.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// More detailed resource gauge with background track and value label.
class DetailedResourceGauge extends StatelessWidget {
  final String label;
  final double value; // 0-100
  final bool isSpiking;
  final Color color;
  final IconData icon;
  final String? subtitle;

  const DetailedResourceGauge({
    super.key,
    required this.label,
    required this.value,
    required this.isSpiking,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.clamp(0, 100);
    final activeColor = isSpiking ? AppTheme.error : color;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: activeColor),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (isSpiking) _SpikeBadge(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${displayValue.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 10),
                        ),
                    ],
                  ),
                ),
                // Compact circular gauge
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: displayValue / 100,
                        strokeWidth: 4,
                        backgroundColor: AppTheme.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                        strokeCap: StrokeCap.round,
                      ),
                      Icon(icon,
                          size: 10, color: activeColor.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: displayValue / 100,
                backgroundColor: AppTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpikeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'SPIKE',
        style: TextStyle(
          color: AppTheme.error,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
