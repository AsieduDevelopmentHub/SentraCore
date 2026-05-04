import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sentracore_dashboard/models/history_sample.dart';
import 'package:sentracore_dashboard/providers/history_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

/// "Logbook" tab is now automated system history.
class _LogbookScreenState extends State<LogbookScreen> {
  _HistoryRange _range = _HistoryRange.day;

  @override
  void initState() {
    super.initState();
    Provider.of<HistoryProvider>(context, listen: false).load();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final all = history.samples;
    final filtered = _filter(all, _range);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SegmentedButton<_HistoryRange>(
                  segments: const [
                    ButtonSegment(value: _HistoryRange.day, label: Text('Day')),
                    ButtonSegment(
                        value: _HistoryRange.week, label: Text('Week')),
                    ButtonSegment(
                        value: _HistoryRange.month, label: Text('Month')),
                    ButtonSegment(
                        value: _HistoryRange.quarter, label: Text('3 mo')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (set) =>
                      setState(() => _range = set.first),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: all.isEmpty
                      ? null
                      : () async {
                          final ok = await _confirmClear(context);
                          if (!ok) return;
                          if (!context.mounted) return;
                          context.read<HistoryProvider>().clear();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Automated history (sampled every ${HistoryProvider.sampleInterval.inSeconds}s) for CPU / memory / disk. Stored locally on this PC.',
              style: TextStyle(
                color: AppTheme.textMutedFor(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: filtered.isEmpty
                    ? _EmptyHistory(loaded: history.loaded)
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Expanded(
                              child: _HistoryChart(
                                title: 'CPU',
                                color: AppTheme.primary,
                                samples: filtered,
                                selector: (s) => s.cpuPercent,
                                suffix: '%',
                                maxY: 100,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _HistoryChart(
                                title: 'Memory',
                                color: AppTheme.accent,
                                samples: filtered,
                                selector: (s) => s.memPercent,
                                suffix: '%',
                                maxY: 100,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _HistoryChart(
                                title: 'Disk pressure',
                                color: AppTheme.warning,
                                samples: filtered,
                                selector: (s) => s.diskPressurePercent,
                                suffix: '%',
                                maxY: 100,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 220,
                              child: _TopProcessesCard(sample: filtered.last),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<HistorySample> _filter(List<HistorySample> src, _HistoryRange range) {
    final now = DateTime.now();
    final minAt = switch (range) {
      _HistoryRange.day => now.subtract(const Duration(days: 1)),
      _HistoryRange.week => now.subtract(const Duration(days: 7)),
      _HistoryRange.month => now.subtract(const Duration(days: 30)),
      _HistoryRange.quarter => now.subtract(const Duration(days: 90)),
    };
    return src.where((s) => s.at.isAfter(minAt)).toList();
  }

  Future<bool> _confirmClear(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This deletes your locally stored history samples from this PC.',
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

enum _HistoryRange { day, week, month, quarter }

class _EmptyHistory extends StatelessWidget {
  final bool loaded;
  const _EmptyHistory({required this.loaded});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 48,
              color: AppTheme.textMutedFor(context),
            ),
            const SizedBox(height: 10),
            Text(
              loaded ? 'No history yet' : 'Loading…',
              style: TextStyle(
                color: AppTheme.textPrimaryFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Connect to the engine and leave SentraCore running. Samples will appear automatically.',
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

class _HistoryChart extends StatelessWidget {
  final String title;
  final Color color;
  final List<HistorySample> samples;
  final double Function(HistorySample s) selector;
  final String suffix;
  final double maxY;

  const _HistoryChart({
    required this.title,
    required this.color,
    required this.samples,
    required this.selector,
    required this.suffix,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final values = samples.map(selector).toList();
    final cur = values.isNotEmpty ? values.last : 0.0;
    final avg =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);

    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i].clamp(0.0, maxY)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${cur.toStringAsFixed(1)}$suffix',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(1)}$suffix',
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mini(context, 'Min', '${min.toStringAsFixed(1)}$suffix'),
                _mini(context, 'Avg', '${avg.toStringAsFixed(1)}$suffix'),
                _mini(context, 'Max', '${max.toStringAsFixed(1)}$suffix'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(BuildContext context, String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k.toUpperCase(),
          style: TextStyle(
            color: AppTheme.textMutedFor(context),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          v,
          style: TextStyle(
            color: AppTheme.textSecondaryFor(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TopProcessesCard extends StatelessWidget {
  final HistorySample sample;
  const _TopProcessesCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    final procs = sample.topProcesses;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Top processes (latest sample)',
                  style: TextStyle(
                    color: AppTheme.textPrimaryFor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmt(sample.at),
                  style: TextStyle(
                    color: AppTheme.textMutedFor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (procs.isEmpty)
              Text(
                'No process data yet.',
                style: TextStyle(color: AppTheme.textMutedFor(context)),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: procs.length,
                  separatorBuilder: (_, __) => Divider(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    height: 8,
                  ),
                  itemBuilder: (context, i) {
                    final p = procs[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimaryFor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _cell(context, 'CPU',
                            '${p.cpuPercent.toStringAsFixed(1)}%'),
                        const SizedBox(width: 10),
                        _cell(context, 'Mem',
                            '${p.memPercent.toStringAsFixed(1)}%'),
                        const SizedBox(width: 10),
                        _cell(context, 'Imp', p.impact.toStringAsFixed(0)),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          k,
          style: TextStyle(
            color: AppTheme.textMutedFor(context),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        Text(
          v,
          style: TextStyle(
            color: AppTheme.textSecondaryFor(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
