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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Text(
                  'Connecting to SentraCore engine…',
                  style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 6),
            child: Text(
              'Waiting for the local engine. This may take a few seconds.',
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
