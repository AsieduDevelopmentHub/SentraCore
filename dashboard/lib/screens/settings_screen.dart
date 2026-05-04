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
  late final TextEditingController _manualSafeguardCtrl;

  @override
  void initState() {
    super.initState();
    _manualSafeguardCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _manualSafeguardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final engine = context.watch<EngineProvider>();
    final pickNames = settings.safeguardPickList(
      engine.processes.map((p) => p.name),
    );

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
          child: Row(
            children: [
              Expanded(
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
              IconButton.filledTonal(
                tooltip: 'Save preferences',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.16),
                  foregroundColor: AppTheme.primary,
                ),
                onPressed: () async {
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
              const SizedBox(height: 20),
              Text(
                'Anomaly labels',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Separate from resource alerts above. This only changes when '
                'NORMAL / ELEVATED / HIGH / SEVERE is shown for baseline deviation '
                '(z-scores). Stricter = labels shift at lower scores.',
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
                  child: SegmentedButton<String>(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppTheme.textPrimaryFor(context)
                            : AppTheme.textSecondaryFor(context),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppTheme.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: 'lenient',
                        label: Text('Lenient'),
                      ),
                      ButtonSegment(
                        value: 'normal',
                        label: Text('Normal'),
                      ),
                      ButtonSegment(
                        value: 'strict',
                        label: Text('Strict'),
                      ),
                    ],
                    selected: {settings.anomalySensitivity},
                    onSelectionChanged: (set) {
                      settings.setAnomalySensitivity(set.first);
                    },
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
                '(graceful terminate) to reduce load. Choose names from what '
                'the engine currently sees, or add another name manually. '
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Safe to close (select processes)',
                            style: TextStyle(
                              color: AppTheme.textSecondaryFor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: !engine.connected
                                ? null
                                : () => engine.refreshProcesses(),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh list'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        !engine.connected
                            ? 'Connect to the engine to load process names from this PC.'
                            : pickNames.isEmpty
                                ? 'No processes yet — tap Refresh after the engine runs a few seconds.'
                                : 'Checked names are allowed for safeguard termination.',
                        style: TextStyle(
                          color: AppTheme.textMutedFor(context),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: pickNames.length,
                        itemBuilder: (context, i) {
                          final name = pickNames[i];
                          return CheckboxListTile(
                            dense: true,
                            enabled: settings.safeguardEnabled,
                            value: settings.safeguardHasName(name),
                            onChanged: settings.safeguardEnabled
                                ? (v) => settings.toggleSafeguardProcessName(
                                      name,
                                      v ?? false,
                                    )
                                : null,
                            title: Text(
                              name,
                              style: TextStyle(
                                color: AppTheme.textPrimaryFor(context),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualSafeguardCtrl,
                              enabled: settings.safeguardEnabled,
                              decoration: InputDecoration(
                                labelText: 'Add other process name',
                                hintText: 'e.g. MyApp.exe',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              style: TextStyle(
                                color: AppTheme.textPrimaryFor(context),
                                fontSize: 13,
                              ),
                              onSubmitted: settings.safeguardEnabled
                                  ? (_) {
                                      settings.addSafeguardProcessNameLine(
                                        _manualSafeguardCtrl.text,
                                      );
                                      _manualSafeguardCtrl.clear();
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: IconButton.filledTonal(
                              tooltip: 'Add name',
                              onPressed: !settings.safeguardEnabled
                                  ? null
                                  : () {
                                      settings.addSafeguardProcessNameLine(
                                        _manualSafeguardCtrl.text,
                                      );
                                      _manualSafeguardCtrl.clear();
                                    },
                              icon: const Icon(Icons.add, size: 22),
                            ),
                          ),
                        ],
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
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppTheme.textPrimaryFor(context)
                            : AppTheme.textSecondaryFor(context),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppTheme.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
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
