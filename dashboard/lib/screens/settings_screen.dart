import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/providers/settings_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _hostCtrl = TextEditingController(text: s.engineHost);
    _portCtrl = TextEditingController(text: '${s.enginePort}');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Engine connection, appearance, and notifications',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Engine',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _hostCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          border: OutlineInputBorder(),
                        ),
                        style: TextStyle(
                          color: AppTheme.textPrimaryFor(context),
                        ),
                        onChanged: settings.setEngineHost,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _portCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: AppTheme.textPrimaryFor(context),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) settings.setEnginePort(n);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Appearance',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_outlined, size: 18),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) {
                      settings.setThemeMode(set.first);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Alerts',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: Text(
                    'Desktop notifications',
                    style: TextStyle(color: AppTheme.textPrimaryFor(context)),
                  ),
                  subtitle: Text(
                    'Show a Windows toast when the engine fires a stress alert',
                    style: TextStyle(
                      color: AppTheme.textMutedFor(context),
                      fontSize: 12,
                    ),
                  ),
                  value: settings.desktopNotificationsEnabled,
                  onChanged: settings.setDesktopNotifications,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  settings.setEngineHost(_hostCtrl.text);
                  final p = int.tryParse(_portCtrl.text);
                  if (p != null) settings.setEnginePort(p);
                  await settings.save();
                  if (!context.mounted) return;
                  await context.read<EngineProvider>().reconnect();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings saved')),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save & reconnect'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
