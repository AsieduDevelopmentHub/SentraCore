import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Screen 3: Detailed process intelligence view — richer than Task Manager.
class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  int _sortColumnIndex = 2; // sort by CPU impact by default
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
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Processes',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('Ranked by sustained system impact',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ]),
              const Spacer(),
              // Process count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text('${provider.processes.length} tracked',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ),
              const SizedBox(width: 12),
              // Search filter
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter by name...',
                    hintStyle:
                        TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    prefixIcon:
                        Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
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
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
            ],
          ),
        ),

        // Summary strip
        _ProcessSummaryStrip(provider: provider),

        // Table
        Expanded(
          child: processes.isEmpty
              ? Center(
                  child: Text('No process data yet.',
                      style: TextStyle(color: AppTheme.textMuted)))
              : _ProcessDataTable(
                  processes: processes,
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  onSort: (col, asc) => setState(() {
                    _sortColumnIndex = col;
                    _sortAscending = asc;
                  }),
                ),
        ),
      ],
    );
  }

  List<ProcessImpact> _sorted(List<ProcessImpact> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.name.compareTo(b.name);
          break;
        case 1:
          cmp = a.pid.compareTo(b.pid);
          break;
        case 2:
          cmp = a.cpuImpact.compareTo(b.cpuImpact);
          break;
        case 3:
          cmp = a.memoryPercent.compareTo(b.memoryPercent);
          break;
        case 4:
          cmp = a.impactScore.compareTo(b.impactScore);
          break;
        default:
          cmp = 0;
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
      color: AppTheme.surfaceLight,
      child: Row(
        children: [
          _SummaryChip(
              'Top CPU',
              '${topCpu.name} (${topCpu.cpuImpact.toStringAsFixed(1)}%)',
              AppTheme.primary),
          const SizedBox(width: 24),
          _SummaryChip(
              'Top Memory',
              '${topMem.name} (${topMem.memoryPercent.toStringAsFixed(1)}%)',
              AppTheme.accent),
          const SizedBox(width: 24),
          _SummaryChip(
              'Highest Impact',
              '${topImpact.name} (${topImpact.impactScore.toStringAsFixed(1)})',
              AppTheme.warning),
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
    return Row(children: [
      Icon(Icons.circle, size: 6, color: color),
      const SizedBox(width: 6),
      Text('$label: ',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _ProcessDataTable extends StatelessWidget {
  final List<ProcessImpact> processes;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;

  const _ProcessDataTable({
    required this.processes,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.surfaceLight),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppTheme.surfaceLight;
            }
            return AppTheme.background;
          }),
          columnSpacing: 20,
          horizontalMargin: 20,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 60,
          sortColumnIndex: sortColumnIndex,
          sortAscending: sortAscending,
          headingTextStyle: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
          columns: [
            DataColumn(label: const Text('PROCESS'), onSort: onSort),
            DataColumn(label: const Text('PID'), numeric: true, onSort: onSort),
            DataColumn(
                label: const Text('CPU IMPACT'), numeric: true, onSort: onSort),
            DataColumn(
                label: const Text('MEMORY'), numeric: true, onSort: onSort),
            DataColumn(
                label: const Text('IMPACT SCORE'),
                numeric: true,
                onSort: onSort),
            const DataColumn(label: Text('SEVERITY')),
          ],
          rows: processes.map((p) => _buildRow(p)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(ProcessImpact p) {
    final severity = _severity(p.impactScore);
    return DataRow(cells: [
      // Process name
      DataCell(Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: severity.$2, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
            child: Text(p.name,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                overflow: TextOverflow.ellipsis)),
      ])),
      // PID
      DataCell(Text('${p.pid}',
          style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontFamily: 'monospace'))),
      // CPU impact with bar
      DataCell(_BarCell(p.cpuImpact, 100, AppTheme.primary, '%')),
      // Memory with bar
      DataCell(_BarCell(p.memoryPercent, 100, AppTheme.accent, '%')),
      // Impact score
      DataCell(Text(
        p.impactScore.toStringAsFixed(1),
        style: TextStyle(
            color: AppTheme.stressColor(_stressLevelForScore(p.impactScore)),
            fontWeight: FontWeight.w600,
            fontSize: 12),
      )),
      // Severity badge
      DataCell(_SeverityBadge(severity.$1, severity.$2)),
    ]);
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

class _BarCell extends StatelessWidget {
  final double value;
  final double maxVal;
  final Color color;
  final String suffix;
  const _BarCell(this.value, this.maxVal, this.color, this.suffix);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${value.toStringAsFixed(1)}$suffix',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (value / maxVal).clamp(0, 1),
              backgroundColor: AppTheme.surfaceLight,
              valueColor:
                  AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.7)),
              minHeight: 3,
            ),
          ),
        ),
      ],
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SeverityBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}
