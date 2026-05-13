import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Settings → Storage panel.
///
/// Shows where the engine keeps its data and offers safe destructive actions:
/// clear cache (non-essential), clear history archive, and reset the
/// behavioral baseline. All actions are confirmed via dialog.
class StorageSettingsSection extends StatefulWidget {
  const StorageSettingsSection({super.key});

  @override
  State<StorageSettingsSection> createState() => _StorageSettingsSectionState();
}

class _StorageSettingsSectionState extends State<StorageSettingsSection> {
  Map<String, dynamic>? _info;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final engine = context.read<EngineProvider>();
    final data = await engine.getStorageInfo();
    if (!mounted) return;
    setState(() {
      _info = data;
      _loading = false;
    });
  }

  Future<void> _openDataFolder() async {
    final root = _info?['root'];
    if (root is! String || root.isEmpty) return;
    try {
      if (Platform.isWindows) {
        await Process.start(
          'explorer',
          [root],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isMacOS) {
        await Process.start('open', [root], mode: ProcessStartMode.detached);
      } else {
        await Process.start(
          'xdg-open',
          [root],
          mode: ProcessStartMode.detached,
        );
      }
    } catch (_) {
      // Best-effort; failures are non-fatal and surface via the user's OS.
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = 'Continue',
  }) async {
    final ctx = context;
    final result = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String _formatBytes(num? raw) {
    final v = (raw ?? 0).toDouble();
    if (v < 1024) return '${v.toStringAsFixed(0)} B';
    if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
    if (v < 1024 * 1024 * 1024) {
      return '${(v / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(v / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<EngineProvider>();
    final info = _info;
    final sections = info?['sections'];
    final history = info?['history'];
    final root = info?['root'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'On-disk data',
                    style: TextStyle(
                      color: AppTheme.textPrimaryFor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: engine.connected ? _refresh : null,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
              ],
            ),
            if (root == null) ...[
              const SizedBox(height: 8),
              Text(
                engine.connected
                    ? 'Loading storage details…'
                    : 'Connect to the engine to view storage usage.',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 12,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              SelectableText(
                root,
                style: TextStyle(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openDataFolder,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Open data folder'),
                ),
              ),
              if (sections is Map) ...[
                const SizedBox(height: 8),
                ..._buildSectionRows(context, sections),
              ],
              const SizedBox(height: 12),
              Text(
                'History archive',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _historySummary(history),
                style: TextStyle(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: !engine.connected
                      ? null
                      : () async {
                          if (!await _confirm(
                            'Clear cache?',
                            'Removes derived artifacts under cache/. '
                                'History, baseline, and preferences are untouched.',
                          )) {
                            return;
                          }
                          await engine.clearEngineCache();
                          await _refresh();
                        },
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Clear cache'),
                ),
                OutlinedButton.icon(
                  onPressed: !engine.connected
                      ? null
                      : () async {
                          if (!await _confirm(
                            'Clear history archive?',
                            'Deletes all stored telemetry samples on this PC. '
                                'Live monitoring is not affected.',
                            confirmLabel: 'Delete history',
                          )) {
                            return;
                          }
                          await engine.clearAllHistory();
                          await _refresh();
                        },
                  icon: const Icon(Icons.history_toggle_off, size: 18),
                  label: const Text('Clear history'),
                ),
                OutlinedButton.icon(
                  onPressed: !engine.connected
                      ? null
                      : () async {
                          if (!await _confirm(
                            'Reset baseline?',
                            'Discards learned normal-behavior statistics. '
                                'The engine will start learning again from now.',
                            confirmLabel: 'Reset baseline',
                          )) {
                            return;
                          }
                          await engine.resetEngineBaseline();
                          await _refresh();
                        },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset baseline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionRows(BuildContext context, Map sections) {
    const order = ['config', 'state', 'history', 'logs', 'cache', 'reports'];
    final rows = <Widget>[];
    for (final key in order) {
      final entry = sections[key];
      if (entry is! Map) continue;
      final bytes = entry['bytes'] as num? ?? 0;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  key,
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatBytes(bytes),
                  style: TextStyle(
                    color: AppTheme.textMutedFor(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  String _historySummary(dynamic history) {
    if (history is! Map) return 'No history archive yet.';
    final files = history['files'];
    final samples = history['total_samples'] ?? 0;
    final bytes = history['total_bytes'] ?? 0;
    final retention = history['retention_days'] ?? 0;
    final fileCount = files is List ? files.length : 0;
    return '$fileCount daily file(s), $samples sample(s), '
        '${_formatBytes(bytes)} on disk. Retention: $retention days.';
  }
}
