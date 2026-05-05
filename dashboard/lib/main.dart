import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/providers/history_provider.dart';
import 'package:sentracore_dashboard/providers/settings_provider.dart';
import 'package:sentracore_dashboard/navigation/dashboard_navigation.dart';
import 'package:sentracore_dashboard/screens/dashboard_screen.dart';
import 'package:sentracore_dashboard/services/desktop_notification_service.dart';
import 'package:sentracore_dashboard/services/engine_bundled_launcher.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupGateApp());
}

class StartupGateApp extends StatefulWidget {
  const StartupGateApp({super.key});

  @override
  State<StartupGateApp> createState() => _StartupGateAppState();
}

class _StartupGateAppState extends State<StartupGateApp> {
  late Future<_BootResult> _boot;

  @override
  void initState() {
    super.initState();
    _boot = _bootstrap();
  }

  Future<_BootResult> _bootstrap() async {
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
    // Engine startup is handled by EngineProvider (single owner) to avoid
    // duplicate launches on app boot.
    return _BootResult(settings: settings, notifications: notifications);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootResult>(
      future: _boot,
      builder: (context, snap) {
        final theme = AppTheme.lightTheme;
        final dark = AppTheme.darkTheme;
        if (!snap.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            darkTheme: dark,
            home: const _StartupSplash(),
          );
        }

        final data = snap.data!;
        return SentraCoreApp(
          settings: data.settings,
          notifications: data.notifications,
        );
      },
    );
  }
}

class _BootResult {
  final SettingsProvider settings;
  final DesktopNotificationService notifications;
  const _BootResult({
    required this.settings,
    required this.notifications,
  });
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SentraCore',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.25),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Starting engine…',
              style: TextStyle(
                  color: AppTheme.textMutedFor(context), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// Startup errors are handled inside the app (EngineProvider), so we no longer
// gate app entry on engine health here.

class SentraCoreApp extends StatefulWidget {
  const SentraCoreApp({
    super.key,
    required this.settings,
    required this.notifications,
  });

  final SettingsProvider settings;
  final DesktopNotificationService notifications;

  @override
  State<SentraCoreApp> createState() => _SentraCoreAppState();
}

class _SentraCoreAppState extends State<SentraCoreApp> {
  @override
  void dispose() {
    // Allow the app to stop the engine on close (owned process only).
    // Users can still kill the process externally; we auto-restart on next launch.
    EngineBundledLauncher.stopOwnedEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DesktopNotificationService>.value(value: widget.notifications),
        ChangeNotifierProvider<SettingsProvider>.value(value: widget.settings),
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) => HistoryProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => EngineProvider(
            settings: widget.settings,
            notifications: widget.notifications,
            history: Provider.of<HistoryProvider>(ctx, listen: false),
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
