import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Table showing top processes ranked by sustained system impact.
class ProcessTable extends StatelessWidget {
  const ProcessTable({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final processes = provider.processes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.apps, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Process Intelligence',
                      style: TextStyle(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Ranked by sustained impact',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textMutedFor(context)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _ColHeader('Process', flex: 3),
                  _ColHeader('Avg CPU', flex: 2),
                  _ColHeader('Avg Mem', flex: 2),
                  _ColHeader('Impact', flex: 2),
                ],
              ),
            ),
            Divider(color: Theme.of(context).dividerColor, height: 12),

            // Process rows
            Expanded(
              child: processes.isEmpty
                  ? Center(
                      child: Text(
                        'Waiting for process data...',
                        style: TextStyle(
                          color: AppTheme.textMutedFor(context),
                          fontSize: 11,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: processes.length.clamp(0, 10),
                      separatorBuilder: (_, __) => Divider(
                        color: Theme.of(context).dividerColor,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final proc = processes[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              // Name
                              Expanded(
                                flex: 3,
                                child: Text(
                                  proc.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Avg CPU
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${proc.avgCpuPercent.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _cpuColor(context, proc.avgCpuPercent),
                                  ),
                                ),
                              ),

                              // Avg Memory
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${proc.avgMemoryPercent.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _memColor(context, proc.avgMemoryPercent),
                                  ),
                                ),
                              ),

                              // Impact score
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _impactColor(proc.impactScore)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    proc.impactScore.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _impactColor(proc.impactScore),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _cpuColor(BuildContext context, double value) {
    if (value > 60) return AppTheme.error;
    if (value > 30) return AppTheme.warning;
    return AppTheme.textSecondaryFor(context);
  }

  Color _memColor(BuildContext context, double value) {
    if (value > 50) return AppTheme.error;
    if (value > 25) return AppTheme.warning;
    return AppTheme.textSecondaryFor(context);
  }

  Color _impactColor(double score) {
    if (score > 50) return AppTheme.error;
    if (score > 20) return AppTheme.warning;
    return AppTheme.accent;
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final int flex;

  const _ColHeader(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.textMutedFor(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
