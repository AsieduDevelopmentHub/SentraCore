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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 14, color: activeColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                if (isSpiking) _SpikeBadge(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${displayValue.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontFamily: 'Outfit',
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (subtitle != null)
                        Text(
                          subtitle!.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ),
                // Compact circular gauge
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: displayValue / 100,
                        strokeWidth: 4.5,
                        backgroundColor: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                        strokeCap: StrokeCap.round,
                      ),
                      Icon(icon,
                          size: 12, color: activeColor.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: displayValue / 100,
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                minHeight: 5,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'SPIKE',
        style: TextStyle(
          color: AppTheme.error,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
