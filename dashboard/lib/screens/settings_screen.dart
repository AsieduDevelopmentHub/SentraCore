import 'package:flutter/material.dart';
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
  late final TextEditingController _safeguardCtrl;
  late final SettingsProvider _settingsRef;

  void _syncSafeguardFromProvider() {
    final t = _settingsRef.safeguardProcessNames;
    if (_safeguardCtrl.text != t) {
      _safeguardCtrl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _settingsRef = context.read<SettingsProvider>();
    _safeguardCtrl = TextEditingController(text: _settingsRef.safeguardProcessNames);
    _settingsRef.addListener(_syncSafeguardFromProvider);
  }

  @override
  void dispose() {
    _settingsRef.removeListener(_syncSafeguardFromProvider);
    _safeguardCtrl.dispose();
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
                'Alert thresholds, optional process safeguard, appearance',
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
                'Resource alerts',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When CPU, memory, or disk pressure stays at or above these '
                'levels for several samples, an alert fires (same signals as the dashboard).',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ThresholdSlider(
                        label: 'CPU pressure threshold',
                        value: settings.alertCpuPercent,
                        onChanged: settings.setAlertCpuPercent,
                      ),
                      const SizedBox(height: 16),
                      _ThresholdSlider(
                        label: 'Memory pressure threshold',
                        value: settings.alertMemoryPercent,
                        onChanged: settings.setAlertMemoryPercent,
                      ),
                      const SizedBox(height: 16),
                      _ThresholdSlider(
                        label: 'Disk I/O pressure threshold',
                        value: settings.alertDiskPressure,
                        onChanged: settings.setAlertDiskPressure,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Safeguard (optional)',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'After an alert fires, the engine may end matching processes '
                '(graceful terminate) to reduce load. One name per line; '
                'include .exe or omit it (e.g. chrome or chrome.exe). '
                'Use only for apps you accept losing unsaved work.',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Enable safeguard terminations',
                        style:
                            TextStyle(color: AppTheme.textPrimaryFor(context)),
                      ),
                      subtitle: Text(
                        'Applies only when an alert has just fired',
                        style: TextStyle(
                          color: AppTheme.textMutedFor(context),
                          fontSize: 12,
                        ),
                      ),
                      value: settings.safeguardEnabled,
                      onChanged: settings.setSafeguardEnabled,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: TextField(
                        controller: _safeguardCtrl,
                        maxLines: 5,
                        enabled: settings.safeguardEnabled,
                        decoration: InputDecoration(
                          labelText: 'Process names',
                          hintText: 'e.g.\nSomeHeavyApp.exe\nAnotherApp',
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                        ),
                        style: TextStyle(
                          color: AppTheme.textPrimaryFor(context),
                          fontSize: 13,
                        ),
                        onChanged: settings.setSafeguardProcessNames,
                      ),
                    ),
                  ],
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
                'Notifications',
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
                    'Windows toast when the engine fires an alert',
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
                  settings.setSafeguardProcessNames(_safeguardCtrl.text);
                  await settings.save();
                  if (!context.mounted) return;
                  final eng = context.read<EngineProvider>();
                  final ok = await eng.pushUserPreferences();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Preferences saved'
                            : 'Saved locally; engine was offline — will sync when connected',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save preferences'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 13,
              ),
            ),
            Text(
              '${value.round()}%',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 100,
          divisions: 99,
          label: '${value.round()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
