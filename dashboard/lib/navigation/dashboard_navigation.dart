import 'package:flutter/scheduler.dart';

/// Registered by [DashboardScreen] / [DiagnosticsScreen] for cross-widget jumps.
class DashboardNavigation {
  DashboardNavigation._();

  /// Switch main rail: 0 Overview … 4 Diagnostics, 5 Hardware, 6 Settings.
  static void Function(int index)? selectMainTab;

  /// Switches Diagnostics inner tab to "Alerts & RCA" (index 1).
  static VoidCallback? focusDiagnosticsAlertsTab;

  static void openAlertsFromNotification() {
    selectMainTab?.call(4);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      focusDiagnosticsAlertsTab?.call();
    });
  }
}
