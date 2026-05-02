import 'package:flutter/material.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Banner shown when the dashboard is not connected to the engine.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Connecting to SentraCore engine at 127.0.0.1:8740...',
            style: TextStyle(
              color: AppTheme.warning,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            'Make sure the engine is running: python -m engine.main',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
