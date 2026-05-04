import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

enum _SortKey { name, pid, cpu, memory, impact }

/// Fixed column widths so CPU / Mem / Impact stay aligned and readable.
const double _kColCpu = 58;
const double _kColMem = 60;
const double _kColImp = 46;

/// Groups multiple PIDs that share the same image name.
class _ProcessGroup {
  _ProcessGroup(this.name, List<ProcessImpact> raw)
      : members = List<ProcessImpact>.from(raw)
          ..sort((a, b) => b.impactScore.compareTo(a.impactScore));

  final String name;
  final List<ProcessImpact> members;

  int get count => members.length;

  int get minPid => members.map((p) => p.pid).fold(0x7fffffff, math.min);

  double get sumCpu => members.fold<double>(0, (a, p) => a + p.cpuImpact);

  double get sumMem => members.fold<double>(0, (a, p) => a + p.memoryPercent);

  double get sumImpact => members.fold<double>(0, (a, p) => a + p.impactScore);
}

/// Screen 3: Process list — grouped by name, compact rows, per-PID actions.
class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  _SortKey _sortKey = _SortKey.impact;
  bool _sortAscending = false;
  String _filter = '';
  final Set<String> _expandedNames = {};

  List<_ProcessGroup> _groupAndSort(List<ProcessImpact> flat) {
    final byName = <String, List<ProcessImpact>>{};
    for (final p in flat) {
      byName.putIfAbsent(p.name, () => []).add(p);
    }
    final groups =
        byName.entries.map((e) => _ProcessGroup(e.key, e.value)).toList();

    int cmpGroups(_ProcessGroup a, _ProcessGroup b) {
      int cmp;
      switch (_sortKey) {
        case _SortKey.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _SortKey.pid:
          cmp = a.minPid.compareTo(b.minPid);
          break;
        case _SortKey.cpu:
          cmp = a.sumCpu.compareTo(b.sumCpu);
          break;
        case _SortKey.memory:
          cmp = a.sumMem.compareTo(b.sumMem);
          break;
        case _SortKey.impact:
          cmp = a.sumImpact.compareTo(b.sumImpact);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    }

    groups.sort(cmpGroups);
    return groups;
  }

  void _toggleExpanded(String name) {
    setState(() {
      if (_expandedNames.contains(name)) {
        _expandedNames.remove(name);
      } else {
        _expandedNames.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final filtered = provider.processes.where((p) {
      if (_filter.isEmpty) return true;
      return p.name.toLowerCase().contains(_filter.toLowerCase());
    }).toList();
    final groups = _groupAndSort(filtered);
    final divider = Theme.of(context).dividerColor.withValues(alpha: 0.35);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Processes',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Grouped by app name. Entries disappear shortly after a PID '
                      'stops appearing in the engine top list (ended or dropped out). '
                      'Memory % is per instance.',
                      style: TextStyle(
                        color: AppTheme.textMutedFor(context),
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLightFor(context),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  '${groups.length} · ${filtered.length} PIDs',
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter…',
                    hintStyle: TextStyle(
                      color: AppTheme.textMutedFor(context),
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 14,
                      color: AppTheme.textMutedFor(context),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceLightFor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 11,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Impact'),
                  selected: _sortKey == _SortKey.impact,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortKey = _SortKey.impact);
                  },
                ),
                ChoiceChip(
                  label: const Text('CPU'),
                  selected: _sortKey == _SortKey.cpu,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortKey = _SortKey.cpu);
                  },
                ),
                ChoiceChip(
                  label: const Text('Memory'),
                  selected: _sortKey == _SortKey.memory,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortKey = _SortKey.memory);
                  },
                ),
                ChoiceChip(
                  label: const Text('Name'),
                  selected: _sortKey == _SortKey.name,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortKey = _SortKey.name);
                  },
                ),
                IconButton(
                  tooltip: _sortAscending ? 'Ascending' : 'Descending',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _sortAscending = !_sortAscending),
                ),
              ],
            ),
          ),
        ),
        _ProcessSummaryStrip(provider: provider),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Text(
                    'No process data yet.',
                    style: TextStyle(color: AppTheme.textMutedFor(context)),
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    if (g.count == 1) {
                      return _CompactProcessTile(
                        p: g.members.first,
                        borderColor: divider,
                        onAction: (action) => _runProcessAction(
                          context,
                          g.members.first,
                          action,
                        ),
                        onOpenActions: () =>
                            _openActionsSheet(context, g.members.first),
                      );
                    }
                    final expanded = _expandedNames.contains(g.name);
                    return _GroupedProcessTile(
                      group: g,
                      expanded: expanded,
                      borderColor: divider,
                      onToggle: () => _toggleExpanded(g.name),
                      onAction: (p, action) =>
                          _runProcessAction(context, p, action),
                      onOpenActions: (p) => _openActionsSheet(context, p),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openActionsSheet(BuildContext context, ProcessImpact p) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        // Constrain + scroll to avoid bottom overflow on short windows.
        final maxH = MediaQuery.of(ctx).size.height * 0.82;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimaryFor(ctx),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'PID ${p.pid}',
                      style: TextStyle(color: AppTheme.textMutedFor(ctx)),
                    ),
                  ),
                  Divider(color: Theme.of(ctx).dividerColor),
                  ListTile(
                    leading: const Icon(Icons.low_priority),
                    title: const Text('Lower CPU priority'),
                    onTap: () => Navigator.pop(ctx, 'lower_priority'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.priority_high),
                    title: const Text('Normal priority'),
                    onTap: () => Navigator.pop(ctx, 'normal_priority'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Icon(Icons.close, color: AppTheme.warning),
                    title: Text(
                      'End process',
                      style: TextStyle(color: AppTheme.warning),
                    ),
                    onTap: () => Navigator.pop(ctx, 'terminate'),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: AppTheme.error),
                    title: Text(
                      'Force kill',
                      style: TextStyle(color: AppTheme.error),
                    ),
                    onTap: () => Navigator.pop(ctx, 'kill'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || !context.mounted) return;
    await _runProcessAction(context, p, selected);
  }

  Future<void> _runProcessAction(
    BuildContext context,
    ProcessImpact p,
    String action,
  ) async {
    if (action == 'terminate' || action == 'kill') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action == 'kill' ? 'Force kill?' : 'End process?'),
          content: Text(
            '${p.name} (PID ${p.pid})\n\n'
            '${action == 'kill' ? 'Kill sends SIGKILL / hard terminate.' : 'Terminate asks the process to exit gracefully.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: Text(action == 'kill' ? 'Kill' : 'End process'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }

    final eng = context.read<EngineProvider>();
    final r = await eng.processAction(p.pid, action);
    if (!context.mounted) return;
    final ok = r['ok'] == true;
    final err = r['error']?.toString() ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Action completed' : err),
        backgroundColor: ok ? null : AppTheme.error,
      ),
    );
  }
}

class _ProcessSummaryStrip extends StatelessWidget {
  final EngineProvider provider;
  const _ProcessSummaryStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.processes.isEmpty) return const SizedBox.shrink();

    final topCpu =
        provider.processes.reduce((a, b) => a.cpuImpact > b.cpuImpact ? a : b);
    final topMem = provider.processes
        .reduce((a, b) => a.memoryPercent > b.memoryPercent ? a : b);
    final topImpact = provider.processes
        .reduce((a, b) => a.impactScore > b.impactScore ? a : b);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppTheme.surfaceLightFor(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryChip(
              'CPU',
              '${topCpu.name} ${topCpu.cpuImpact.toStringAsFixed(1)}%',
              AppTheme.primary,
            ),
            const SizedBox(width: 16),
            _SummaryChip(
              'Mem',
              '${topMem.name} ${topMem.memoryPercent.toStringAsFixed(1)}%',
              AppTheme.accent,
            ),
            const SizedBox(width: 16),
            _SummaryChip(
              'Impact',
              '${topImpact.name} ${topImpact.impactScore.toStringAsFixed(1)}',
              AppTheme.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 5, color: color),
        const SizedBox(width: 4),
        Text(
          '$label ',
          style: TextStyle(color: AppTheme.textMutedFor(context), fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Group header + expandable PIDs.
class _GroupedProcessTile extends StatelessWidget {
  final _ProcessGroup group;
  final bool expanded;
  final Color borderColor;
  final VoidCallback onToggle;
  final void Function(ProcessImpact p, String action) onAction;
  final void Function(ProcessImpact p) onOpenActions;

  const _GroupedProcessTile({
    required this.group,
    required this.expanded,
    required this.borderColor,
    required this.onToggle,
    required this.onAction,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final sev = _severity(group.members.first.impactScore);
    final muted = AppTheme.textMutedFor(context);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: muted,
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 8),
                    decoration:
                        BoxDecoration(color: sev.$2, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      group.name,
                      style: TextStyle(
                        color: AppTheme.textPrimaryFor(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '×${group.count}',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  _MetricColumn(
                    label: 'CPU',
                    value: group.sumCpu,
                    color: AppTheme.primary,
                    width: _kColCpu,
                  ),
                  _MetricColumn(
                    label: 'Mem',
                    value: group.sumMem,
                    color: AppTheme.accent,
                    width: _kColMem,
                  ),
                  SizedBox(
                    width: _kColImp,
                    child: Text(
                      group.sumImpact.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: AppTheme.stressColor(
                          _stressLevelForScore(
                            group.members
                                .map((e) => e.impactScore)
                                .reduce(math.max),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                for (var i = 0; i < group.members.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: borderColor),
                  _CompactPidRow(
                    p: group.members[i],
                    indent: true,
                    onAction: (a) => onAction(group.members[i], a),
                    onOpenActions: () => onOpenActions(group.members[i]),
                  ),
                ],
              ],
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  (String, Color) _severity(double score) {
    if (score > 70) return ('Critical', AppTheme.stressCritical);
    if (score > 40) return ('High', AppTheme.stressHigh);
    if (score > 20) return ('Moderate', AppTheme.stressModerate);
    return ('Low', AppTheme.stressLow);
  }

  String _stressLevelForScore(double score) {
    if (score > 70) return 'critical';
    if (score > 40) return 'high';
    if (score > 20) return 'moderate';
    return 'low';
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final double width;

  const _MetricColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textMutedFor(context),
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single process — one dense row.
class _CompactProcessTile extends StatelessWidget {
  final ProcessImpact p;
  final Color borderColor;
  final void Function(String action) onAction;
  final VoidCallback onOpenActions;

  const _CompactProcessTile({
    required this.p,
    required this.borderColor,
    required this.onAction,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: borderColor),
      ),
      child: _CompactPidRow(
        p: p,
        indent: false,
        onAction: onAction,
        onOpenActions: onOpenActions,
      ),
    );
  }
}

class _CompactPidRow extends StatelessWidget {
  final ProcessImpact p;
  final bool indent;
  final void Function(String action) onAction;
  final VoidCallback onOpenActions;

  const _CompactPidRow({
    required this.p,
    required this.indent,
    required this.onAction,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final sev = _severity(p.impactScore);
    final muted = AppTheme.textMutedFor(context);

    return InkWell(
      onTap: onOpenActions,
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent ? 28 : 10, 8, 8, 8),
        child: Row(
          children: [
            if (!indent) ...[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 8),
                decoration:
                    BoxDecoration(color: sev.$2, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              Expanded(
                child: Text(
                  'PID ${p.pid}',
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            SizedBox(
              width: _kColCpu,
              child: Text(
                '${p.cpuImpact.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(
              width: _kColMem,
              child: Text(
                '${p.memoryPercent.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(
              width: _kColImp,
              child: Text(
                p.impactScore.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color:
                      AppTheme.stressColor(_stressLevelForScore(p.impactScore)),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              iconSize: 22,
              icon: Icon(Icons.more_vert, color: muted),
              onSelected: onAction,
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'lower_priority',
                  child: Text('Lower CPU priority'),
                ),
                const PopupMenuItem(
                  value: 'normal_priority',
                  child: Text('Normal priority'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'terminate',
                  child: Text('End process'),
                ),
                PopupMenuItem(
                  value: 'kill',
                  child: Text(
                    'Force kill',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _severity(double score) {
    if (score > 70) return ('Critical', AppTheme.stressCritical);
    if (score > 40) return ('High', AppTheme.stressHigh);
    if (score > 20) return ('Moderate', AppTheme.stressModerate);
    return ('Low', AppTheme.stressLow);
  }

  String _stressLevelForScore(double score) {
    if (score > 70) return 'critical';
    if (score > 40) return 'high';
    if (score > 20) return 'moderate';
    return 'low';
  }
}
