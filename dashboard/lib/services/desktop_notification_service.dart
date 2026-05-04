import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Windows toast-style alerts via flutter_local_notifications.
class DesktopNotificationService {
  DesktopNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb || !Platform.isWindows) {
      _ready = false;
      return;
    }
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          windows: WindowsInitializationSettings(
            appName: 'SentraCore',
            appUserModelId: 'SentraCore.Dashboard.Notifications',
            guid: 'c3d4e5f6-a7b8-4c9d-0e1f-223344556677',
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> show({required String title, required String body}) async {
    if (!_ready) return;
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (_) {
      // Ignore — OS may block notifications until user enables them.
    }
  }
}
