import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/providers/logbook_provider.dart';
import 'package:sentracore_dashboard/providers/settings_provider.dart';
import 'package:sentracore_dashboard/navigation/dashboard_navigation.dart';
import 'package:sentracore_dashboard/screens/dashboard_screen.dart';
import 'package:sentracore_dashboard/services/desktop_notification_service.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = DesktopNotificationService();
  await notifications.init(
    onDidReceiveNotificationResponse: (response) {
      if (response.notificationResponseType ==
          NotificationResponseType.selectedNotification) {
        DashboardNavigation.openAlertsFromNotification();
      }
    },
  );
  final settings = SettingsProvider();
  await settings.load();
  runApp(SentraCoreApp(
    settings: settings,
    notifications: notifications,
  ));
}

class SentraCoreApp extends StatelessWidget {
  const SentraCoreApp({
    super.key,
    required this.settings,
    required this.notifications,
  });

  final SettingsProvider settings;
  final DesktopNotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DesktopNotificationService>.value(value: notifications),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<LogbookProvider>(
          create: (_) => LogbookProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => EngineProvider(
            settings: settings,
            notifications: notifications,
          )..connect(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          return MaterialApp(
            title: 'SentraCore Intelligence',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: s.themeMode,
            home: const DashboardScreen(),
          );
        },
      ),
    );
  }
}
