import 'package:flutter/scheduler.dart';

/// Registered by [DashboardScreen] / [DiagnosticsScreen] for cross-widget jumps.
class DashboardNavigation {
  DashboardNavigation._();

  /// Switch main rail: 0 Overview … 3 Diagnostics … 4 Settings.
  static void Function(int index)? selectMainTab;

  /// Switches Diagnostics inner tab to "Alerts & RCA" (index 1).
  static VoidCallback? focusDiagnosticsAlertsTab;

  static void openAlertsFromNotification() {
    selectMainTab?.call(3);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      focusDiagnosticsAlertsTab?.call();
    });
  }
}
