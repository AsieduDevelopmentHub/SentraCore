import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

enum _SortKey { name, pid, cpu, memory, impact }

/// Screen 3: Detailed process intelligence — card layout with actions.
class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  _SortKey _sortKey = _SortKey.impact;
  bool _sortAscending = false;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final processes = _sorted(provider.processes.where((p) {
      if (_filter.isEmpty) return true;
      return p.name.toLowerCase().contains(_filter.toLowerCase());
    }).toList());

    return Column(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processes',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Top processes by impact — not every app. Memory % is each '
                    'process’s share of RAM; it will not add up to overall usage.',
                    style: TextStyle(
                      color: AppTheme.textMutedFor(context),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLightFor(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  '${provider.processes.length} tracked',
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter by name...',
                    hintStyle: TextStyle(
                      color: AppTheme.textMutedFor(context),
                      fontSize: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 16,
                      color: AppTheme.textMutedFor(context),
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceLightFor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 12,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Impact'),
                  selected: _sortKey == _SortKey.impact,
                  onSelected: (_) => setState(() => _sortKey = _SortKey.impact),
                ),
                ChoiceChip(
                  label: const Text('CPU'),
                  selected: _sortKey == _SortKey.cpu,
                  onSelected: (_) => setState(() => _sortKey = _SortKey.cpu),
                ),
                ChoiceChip(
                  label: const Text('Memory'),
                  selected: _sortKey == _SortKey.memory,
                  onSelected: (_) => setState(() => _sortKey = _SortKey.memory),
                ),
                ChoiceChip(
                  label: const Text('Name'),
                  selected: _sortKey == _SortKey.name,
                  onSelected: (_) => setState(() => _sortKey = _SortKey.name),
                ),
                IconButton(
                  tooltip: _sortAscending ? 'Ascending' : 'Descending',
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 20,
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
          child: processes.isEmpty
              ? Center(
                  child: Text(
                    'No process data yet.',
                    style: TextStyle(color: AppTheme.textMutedFor(context)),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: processes.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProcessCard(
                        p: processes[i],
                        onAction: (action) =>
                            _runProcessAction(context, processes[i], action),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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

  List<ProcessImpact> _sorted(List<ProcessImpact> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _SortKey.name:
          cmp = a.name.compareTo(b.name);
          break;
        case _SortKey.pid:
          cmp = a.pid.compareTo(b.pid);
          break;
        case _SortKey.cpu:
          cmp = a.cpuImpact.compareTo(b.cpuImpact);
          break;
        case _SortKey.memory:
          cmp = a.memoryPercent.compareTo(b.memoryPercent);
          break;
        case _SortKey.impact:
          cmp = a.impactScore.compareTo(b.impactScore);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppTheme.surfaceLightFor(context),
      child: Row(
        children: [
          _SummaryChip(
            'Top CPU',
            '${topCpu.name} (${topCpu.cpuImpact.toStringAsFixed(1)}%)',
            AppTheme.primary,
          ),
          const SizedBox(width: 24),
          _SummaryChip(
            'Top Memory',
            '${topMem.name} (${topMem.memoryPercent.toStringAsFixed(1)}%)',
            AppTheme.accent,
          ),
          const SizedBox(width: 24),
          _SummaryChip(
            'Highest Impact',
            '${topImpact.name} (${topImpact.impactScore.toStringAsFixed(1)})',
            AppTheme.warning,
          ),
        ],
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
        Icon(Icons.circle, size: 6, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(color: AppTheme.textMutedFor(context), fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProcessCard extends StatelessWidget {
  final ProcessImpact p;
  final void Function(String action) onAction;

  const _ProcessCard({required this.p, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final sev = _severity(p.impactScore);
    final border = Theme.of(context).dividerColor.withValues(alpha: 0.35);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: sev.$2,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: AppTheme.textPrimaryFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _MiniChip(
                              'PID ${p.pid}', AppTheme.textMutedFor(context)),
                          _MiniChip(
                            'Avg CPU ${p.avgCpuPercent.toStringAsFixed(1)}%',
                            AppTheme.primary,
                          ),
                          _MiniChip(
                            'Avg mem ${p.avgMemoryPercent.toStringAsFixed(1)}%',
                            AppTheme.accent,
                          ),
                          _MiniChip(sev.$1, sev.$2),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.impactScore.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.stressColor(
                          _stressLevelForScore(p.impactScore),
                        ),
                      ),
                    ),
                    Text(
                      'impact',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMutedFor(context),
                        letterSpacing: 0.4,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Process actions',
                      icon: Icon(
                        Icons.more_vert,
                        color: AppTheme.textMutedFor(context),
                      ),
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
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricBar(
                    label: 'Current CPU',
                    value: p.cpuImpact,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricBar(
                    label: 'Current memory',
                    value: p.memoryPercent,
                    color: AppTheme.accent,
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

class _MiniChip extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniChip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
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
                fontSize: 10,
                color: AppTheme.textMutedFor(context),
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 5,
            backgroundColor:
                Theme.of(context).dividerColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              color.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}
