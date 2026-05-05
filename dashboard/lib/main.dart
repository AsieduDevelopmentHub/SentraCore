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

  Future<_BootResult> _bootstrap({bool userRetry = false}) async {
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

    // READY GATE (strict): do not enter the app until engine is healthy.
    final out = userRetry
        ? await EngineBundledLauncher.ensureReadyUserRetry()
        : await EngineBundledLauncher.ensureReady();
    return _BootResult(
        settings: settings, notifications: notifications, gate: out);
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
        if (!data.gate.success) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            darkTheme: dark,
            home: _StartupError(
              message: data.gate.message ?? 'Engine failed to start.',
              onRetry: () =>
                  setState(() => _boot = _bootstrap(userRetry: true)),
            ),
          );
        }

        return SentraCoreApp(
            settings: data.settings, notifications: data.notifications);
      },
    );
  }
}

class _BootResult {
  final SettingsProvider settings;
  final DesktopNotificationService notifications;
  final EngineBootstrapOutcome gate;
  const _BootResult({
    required this.settings,
    required this.notifications,
    required this.gate,
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

class _StartupError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _StartupError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Engine failed to start',
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(color: AppTheme.textMutedFor(context)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) => HistoryProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => EngineProvider(
            settings: settings,
            notifications: notifications,
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
