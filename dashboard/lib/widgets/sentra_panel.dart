import 'package:flutter/material.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Consistent card shell for dashboard panels (design.md: 8–12px radius, calm, layered).
class SentraPanel extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final Color? iconColor;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const SentraPanel({
    super.key,
    this.title,
    this.titleIcon,
    this.iconColor,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(
                      titleIcon,
                      size: 18,
                      color: iconColor ?? AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: AppTheme.textPrimaryFor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              Divider(
                height: 28,
                thickness: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.85),
              ),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
