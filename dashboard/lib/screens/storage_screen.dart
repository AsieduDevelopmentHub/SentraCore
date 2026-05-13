import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Two-panel page: "Free up space" (cleanup scan) + "Largest files" (browser).
///
/// Both panels are read-mostly: the engine produces the data; the UI lets the
/// user preview before any deletion. The Free-up-space panel requires a
/// successful scan before "Recycle / Permanently delete" can be invoked,
/// because the API gates deletes on a server-side scan_id.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Storage',
            style: TextStyle(
              color: AppTheme.textPrimaryFor(context),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find what is using your disk and reclaim space safely.',
            style: TextStyle(
              color: AppTheme.textMutedFor(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Free up space'),
              Tab(text: 'Largest files'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _CleanupPanel(),
                _LargeFilesPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Cleanup panel
// --------------------------------------------------------------------------- //

class _CleanupPanel extends StatefulWidget {
  const _CleanupPanel();

  @override
  State<_CleanupPanel> createState() => _CleanupPanelState();
}

class _CleanupPanelState extends State<_CleanupPanel> {
  bool _scanning = false;
  bool _applying = false;
  String? _scanId;
  String? _osLabel;
  final bool _supportsRecycle = true;
  List<Map<String, dynamic>> _categories = const [];
  final Set<String> _selected = <String>{};
  String? _lastError;
  Map<String, dynamic>? _lastApply;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _lastError = null;
      _lastApply = null;
    });
    final engine = context.read<EngineProvider>();
    final res = await engine.runCleanupScan();
    if (!mounted) return;

    if (res == null || res['ok'] != true) {
      setState(() {
        _scanning = false;
        _lastError = (res?['error'] as String?) ?? 'Scan failed';
      });
      return;
    }
    final cats = (res['categories'] as List?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        const <Map<String, dynamic>>[];

    setState(() {
      _scanId = res['scan_id'] as String?;
      _osLabel = res['os'] as String?;
      _categories = cats;
      _selected
        ..clear()
        // Pre-select buckets that actually have something to delete.
        ..addAll(cats
            .where((c) => ((c['bytes'] as num?) ?? 0) > 0)
            .map((c) => c['id'] as String));
      _scanning = false;
    });
  }

  Future<void> _apply({required bool permanent}) async {
    final scanId = _scanId;
    if (scanId == null || _selected.isEmpty) return;
    final confirm = await _confirmDialog(
      title: permanent ? 'Permanently delete?' : 'Move to Recycle Bin?',
      message: permanent
          ? 'Files will be removed and cannot be recovered.'
          : 'Files will be moved to the Recycle Bin where you can restore them.',
      confirmLabel: permanent ? 'Delete' : 'Recycle',
    );
    if (!confirm || !mounted) return;

    setState(() {
      _applying = true;
      _lastError = null;
      _lastApply = null;
    });
    final engine = context.read<EngineProvider>();
    final res = await engine.applyCleanup(
      scanId: scanId,
      categoryIds: _selected.toList(),
      mode: permanent ? 'permanent' : 'recycle',
    );
    if (!mounted) return;

    setState(() {
      _applying = false;
      if (res == null || res['ok'] != true) {
        _lastError = (res?['error'] as String?) ?? 'Cleanup failed';
      } else {
        _lastApply = res;
        // Force a re-scan to refresh the numbers shown.
        _scanId = null;
        _categories = const [];
        _selected.clear();
      }
    });
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
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

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<EngineProvider>();
    final hasResults = _categories.isNotEmpty;
    final totalBytes = _categories.fold<int>(
      0,
      (a, c) => a + (((c['bytes'] as num?) ?? 0).toInt()),
    );
    final selectedBytes = _categories
        .where((c) => _selected.contains(c['id']))
        .fold<int>(0, (a, c) => a + (((c['bytes'] as num?) ?? 0).toInt()));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasResults
                              ? 'Reclaimable: ${_formatBytes(totalBytes)} • Selected: ${_formatBytes(selectedBytes)}'
                              : 'Run a scan to find safe-to-clean files.',
                          style: TextStyle(
                            color: AppTheme.textPrimaryFor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_osLabel != null)
                        Text(
                          _osLabel!.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.textMutedFor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _scanning || !engine.connected ? null : _scan,
                        icon: _scanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(_scanning ? 'Scanning…' : 'Scan now'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed:
                            hasResults && _selected.isNotEmpty && !_applying
                                ? () => _apply(permanent: false)
                                : null,
                        icon: _applying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Move to Recycle Bin'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed:
                            hasResults && _selected.isNotEmpty && !_applying
                                ? () => _apply(permanent: true)
                                : null,
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Delete permanently'),
                      ),
                    ],
                  ),
                  if (_lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lastError!,
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_lastApply != null) ...[
                    const SizedBox(height: 8),
                    _ApplyResultBanner(result: _lastApply!),
                  ],
                  if (!_supportsRecycle) ...[
                    const SizedBox(height: 4),
                    Text(
                      'send2trash is not installed; "Move to Recycle Bin" '
                      'will fall back to permanent delete.',
                      style: TextStyle(
                        color: AppTheme.textMutedFor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (hasResults)
            ..._categories.map(_categoryCard)
          else if (!_scanning)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    engine.connected
                        ? 'No scan yet. Press "Scan now" to see what can be cleaned.'
                        : 'Connect to the engine to scan for cleanup opportunities.',
                    style: TextStyle(
                      color: AppTheme.textMutedFor(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryCard(Map<String, dynamic> cat) {
    final id = (cat['id'] as String?) ?? '';
    final label = (cat['label'] as String?) ?? id;
    final desc = (cat['description'] as String?) ?? '';
    final bytes = ((cat['bytes'] as num?) ?? 0).toInt();
    final fileCount = ((cat['file_count'] as num?) ?? 0).toInt();
    final samples = (cat['samples'] as List?) ?? const [];
    final roots = (cat['roots'] as List?) ?? const [];
    final selected = _selected.contains(id);
    final empty = bytes == 0 && fileCount == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: empty
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          });
                        },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: AppTheme.textPrimaryFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          color: AppTheme.textMutedFor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatBytes(bytes),
                      style: TextStyle(
                        color: AppTheme.textPrimaryFor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$fileCount files',
                      style: TextStyle(
                        color: AppTheme.textMutedFor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (roots.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final r in roots)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    r.toString(),
                    style: TextStyle(
                      color: AppTheme.textSecondaryFor(context),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
            if (samples.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Largest samples',
                style: TextStyle(
                  color: AppTheme.textMutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              for (final s in samples.take(5)) _sampleRow(s as Map),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sampleRow(Map sample) {
    final path = (sample['path'] as String?) ?? '';
    final size = ((sample['size'] as num?) ?? 0).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatBytes(size),
            style: TextStyle(
              color: AppTheme.textMutedFor(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyResultBanner extends StatelessWidget {
  const _ApplyResultBanner({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final removed = ((result['removed'] as num?) ?? 0).toInt();
    final freed = ((result['bytes_freed'] as num?) ?? 0).toInt();
    final skipped = ((result['skipped'] as num?) ?? 0).toInt();
    final errors = (result['errors'] as List?) ?? const [];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(10),
      child: Text(
        'Freed ${_formatBytes(freed)} across $removed files'
        '${skipped > 0 ? ' • $skipped skipped' : ''}'
        '${errors.isNotEmpty ? ' • ${errors.length} error(s)' : ''}',
        style: TextStyle(
          color: AppTheme.textPrimaryFor(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Large files panel
// --------------------------------------------------------------------------- //

class _LargeFilesPanel extends StatefulWidget {
  const _LargeFilesPanel();

  @override
  State<_LargeFilesPanel> createState() => _LargeFilesPanelState();
}

class _LargeFilesPanelState extends State<_LargeFilesPanel> {
  late final TextEditingController _pathCtrl =
      TextEditingController(text: _defaultPath());
  double _minMb = 100;
  int _limit = 200;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];

  String _defaultPath() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    return home;
  }

  Future<void> _search() async {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final engine = context.read<EngineProvider>();
    final res = await engine.findLargeFiles(
      path: path,
      minMb: _minMb,
      limit: _limit,
    );
    if (!mounted) return;
    if (res == null || res['ok'] != true) {
      setState(() {
        _busy = false;
        _error = (res?['error'] as String?) ?? 'Search failed';
        _results = const [];
      });
      return;
    }
    final items = (res['results'] as List?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        const <Map<String, dynamic>>[];
    setState(() {
      _busy = false;
      _results = items;
    });
  }

  Future<void> _openContaining(String parent) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer', [parent],
            mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [parent], mode: ProcessStartMode.detached);
      } else {
        await Process.start('xdg-open', [parent],
            mode: ProcessStartMode.detached);
      }
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<EngineProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Search a folder',
                    style: TextStyle(
                      color: AppTheme.textPrimaryFor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pathCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Folder path',
                      hintText: 'e.g. C:\\Users\\you',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Min size: ${_minMb.toStringAsFixed(0)} MB',
                              style: TextStyle(
                                color: AppTheme.textSecondaryFor(context),
                                fontSize: 12,
                              ),
                            ),
                            Slider(
                              value: _minMb,
                              min: 10,
                              max: 5000,
                              divisions: 99,
                              label: '${_minMb.toStringAsFixed(0)} MB',
                              onChanged: (v) => setState(() => _minMb = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Max results: $_limit',
                              style: TextStyle(
                                color: AppTheme.textSecondaryFor(context),
                                fontSize: 12,
                              ),
                            ),
                            Slider(
                              value: _limit.toDouble(),
                              min: 25,
                              max: 1000,
                              divisions: 39,
                              label: '$_limit',
                              onChanged: (v) =>
                                  setState(() => _limit = v.toInt()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy || !engine.connected ? null : _search,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_busy ? 'Searching…' : 'Find largest files'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: TextStyle(color: AppTheme.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty && !_busy)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No results yet. Pick a folder and press "Find largest files".',
                    style: TextStyle(
                      color: AppTheme.textMutedFor(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _results.length; i++)
                    _LargeFileRow(
                      result: _results[i],
                      onOpen: _openContaining,
                      isFirst: i == 0,
                      isLast: i == _results.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LargeFileRow extends StatelessWidget {
  const _LargeFileRow({
    required this.result,
    required this.onOpen,
    required this.isFirst,
    required this.isLast,
  });
  final Map<String, dynamic> result;
  final void Function(String parent) onOpen;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final path = (result['path'] as String?) ?? '';
    final parent = (result['parent'] as String?) ?? '';
    final size = ((result['size'] as num?) ?? 0).toInt();
    final mtime = ((result['mtime'] as num?) ?? 0).toDouble();
    final when = mtime > 0
        ? DateTime.fromMillisecondsSinceEpoch((mtime * 1000).toInt()).toLocal()
        : null;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        subtitle: Text(
          when != null
              ? 'modified ${when.toIso8601String().split('.').first}'
              : ' ',
          style: TextStyle(
            color: AppTheme.textMutedFor(context),
            fontSize: 11,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatBytes(size),
              style: TextStyle(
                color: AppTheme.textPrimaryFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Open containing folder',
              onPressed: () => onOpen(parent),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Shared helpers
// --------------------------------------------------------------------------- //

String _formatBytes(num? raw) {
  final v = (raw ?? 0).toDouble();
  if (v < 1024) return '${v.toStringAsFixed(0)} B';
  if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
  if (v < 1024 * 1024 * 1024) {
    return '${(v / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(v / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
