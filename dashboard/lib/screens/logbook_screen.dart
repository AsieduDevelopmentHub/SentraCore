import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sentracore_dashboard/models/logbook_entry.dart';
import 'package:sentracore_dashboard/providers/logbook_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  String _query = '';
  _LogbookRange _range = _LogbookRange.all;

  @override
  void initState() {
    super.initState();
    // Safe in initState: no async gap, just kick off provider load.
    Provider.of<LogbookProvider>(context, listen: false).load();
  }

  @override
  Widget build(BuildContext context) {
    final logbook = context.watch<LogbookProvider>();
    final all = logbook.entries;
    final filtered = _filter(all);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Logbook',
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Clear logbook',
                  onPressed: all.isEmpty
                      ? null
                      : () async {
                          final ok = await _confirmClear(context);
                          if (!ok) return;
                          if (!context.mounted) return;
                          context.read<LogbookProvider>().clear();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Manually record past process metrics (CPU / memory / disk pressure) '
              'with a timestamp. Stored locally on this PC.',
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by process name or notes',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<_LogbookRange>(
                  segments: const [
                    ButtonSegment(
                      value: _LogbookRange.today,
                      label: Text('Today'),
                    ),
                    ButtonSegment(
                      value: _LogbookRange.last7Days,
                      label: Text('7d'),
                    ),
                    ButtonSegment(
                      value: _LogbookRange.all,
                      label: Text('All'),
                    ),
                  ],
                  selected: {_range},
                  onSelectionChanged: (set) =>
                      setState(() => _range = set.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: filtered.isEmpty
                    ? _EmptyLogbook(loaded: logbook.loaded)
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Theme.of(context).dividerColor),
                        itemBuilder: (context, i) {
                          final e = filtered[i];
                          return _LogEntryTile(
                            entry: e,
                            onDelete: () => context
                                .read<LogbookProvider>()
                                .deleteById(e.id),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LogbookEntry> _filter(List<LogbookEntry> src) {
    final q = _query.trim().toLowerCase();
    final now = DateTime.now();
    DateTime? minAt;
    if (_range == _LogbookRange.today) {
      minAt = DateTime(now.year, now.month, now.day);
    } else if (_range == _LogbookRange.last7Days) {
      minAt = now.subtract(const Duration(days: 7));
    }

    return src.where((e) {
      if (minAt != null && e.at.isBefore(minAt)) return false;
      if (q.isEmpty) return true;
      return e.processName.toLowerCase().contains(q) ||
          e.notes.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final created = await showDialog<LogbookEntry>(
      context: context,
      builder: (_) => const _AddLogEntryDialog(),
    );
    if (created == null) return;
    if (!context.mounted) return;
    context.read<LogbookProvider>().add(created);
  }

  Future<bool> _confirmClear(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear logbook?'),
        content: const Text(
          'This deletes all logged entries from this PC.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    return res == true;
  }
}

enum _LogbookRange { today, last7Days, all }

class _EmptyLogbook extends StatelessWidget {
  final bool loaded;
  const _EmptyLogbook({required this.loaded});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 48,
              color: AppTheme.textMutedFor(context),
            ),
            const SizedBox(height: 10),
            Text(
              loaded ? 'No entries yet' : 'Loading…',
              style: TextStyle(
                color: AppTheme.textPrimaryFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap “Add entry” to log metrics from a previous time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogbookEntry entry;
  final VoidCallback onDelete;

  const _LogEntryTile({
    required this.entry,
    required this.onDelete,
  });

  String _fmtDateTime(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = entry.processName.trim().isEmpty
        ? 'Unknown process'
        : entry.processName;
    return ListTile(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textPrimaryFor(context),
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fmtDateTime(entry.at),
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(context, 'CPU', '${entry.cpuPercent.round()}%'),
                _pill(context, 'Mem', '${entry.memPercent.round()}%'),
                _pill(context, 'Disk', '${entry.diskPressurePercent.round()}%'),
              ],
            ),
            if (entry.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.notes.trim(),
                style: TextStyle(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }

  Widget _pill(BuildContext context, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        '$k: $v',
        style: TextStyle(
          color: AppTheme.textMutedFor(context),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddLogEntryDialog extends StatefulWidget {
  const _AddLogEntryDialog();

  @override
  State<_AddLogEntryDialog> createState() => _AddLogEntryDialogState();
}

class _AddLogEntryDialogState extends State<_AddLogEntryDialog> {
  final _processCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _at = DateTime.now();
  double _cpu = 0;
  double _mem = 0;
  double _disk = 0;

  @override
  void dispose() {
    _processCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add log entry'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _processCtrl,
                decoration: const InputDecoration(
                  labelText: 'Process / app name',
                  hintText: 'e.g. chrome.exe or Blender',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _at,
                          firstDate: DateTime(2000),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked == null) return;
                        if (!context.mounted) return;
                        final tod = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_at),
                        );
                        if (tod == null) return;
                        setState(() {
                          _at = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            tod.hour,
                            tod.minute,
                          );
                        });
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(_prettyAt(_at)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSlider(
                label: 'CPU',
                value: _cpu,
                onChanged: (v) => setState(() => _cpu = v),
              ),
              const SizedBox(height: 6),
              _MetricSlider(
                label: 'Memory',
                value: _mem,
                onChanged: (v) => setState(() => _mem = v),
              ),
              const SizedBox(height: 6),
              _MetricSlider(
                label: 'Disk pressure',
                value: _disk,
                onChanged: (v) => setState(() => _disk = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'What was happening? Any context?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final now = DateTime.now();
            final id =
                '${now.microsecondsSinceEpoch}_${_processCtrl.text.hashCode}';
            Navigator.pop(
              context,
              LogbookEntry(
                id: id,
                at: _at,
                processName: _processCtrl.text.trim(),
                cpuPercent: _cpu,
                memPercent: _mem,
                diskPressurePercent: _disk,
                notes: _notesCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  String _prettyAt(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _MetricSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _MetricSlider({
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
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${value.round()}%',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0.0, 100.0).toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: '${value.round()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
