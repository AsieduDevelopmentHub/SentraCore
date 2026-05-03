import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/models/system_state.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/responsive_builder.dart';

/// Screen 4: Full event log with severity filter + alert history with expandable RCA.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _eventSeverityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Diagnostics',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text('Event log and alert history with root cause analysis',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
            const Spacer(),
            _AlertCountBadge(provider: provider),
          ]),
        ),
        // Tabs
        Container(
          color: AppTheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.list_alt, size: 14),
                  const SizedBox(width: 6),
                  Text('Event Log (${provider.events.length})'),
                ]),
              ),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.notifications_active_outlined, size: 14),
                  const SizedBox(width: 6),
                  const Text('Alerts & RCA'),
                ]),
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _EventLogTab(
                events: provider.events,
                severityFilter: _eventSeverityFilter,
                onFilterChanged: (v) =>
                    setState(() => _eventSeverityFilter = v),
              ),
              _AlertsRcaTab(provider: provider),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertCountBadge extends StatelessWidget {
  final EngineProvider provider;
  const _AlertCountBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    final count = provider.currentState?.alert.totalFired ?? 0;
    final inCooldown = provider.currentState?.alert.inCooldown ?? false;

    return Row(children: [
      if (inCooldown) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.hourglass_bottom, size: 11, color: AppTheme.info),
            const SizedBox(width: 4),
            Text('Cooldown active',
                style: TextStyle(color: AppTheme.info, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
      ],
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 13, color: AppTheme.error),
          const SizedBox(width: 5),
          Text('$count alerts total',
              style: TextStyle(
                  color: AppTheme.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

class _EventLogTab extends StatelessWidget {
  final List<SystemEvent> events;
  final String severityFilter;
  final ValueChanged<String> onFilterChanged;

  const _EventLogTab({
    required this.events,
    required this.severityFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = severityFilter == 'all'
        ? events
        : events.where((e) => e.severity == severityFilter).toList();

    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceLight,
          child: Row(
            children: [
              Text('Filter: ',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              const SizedBox(width: 8),
              for (final sev in ['all', 'info', 'warning', 'critical'])
                _FilterChip(
                  label: sev,
                  isSelected: severityFilter == sev,
                  onTap: () => onFilterChanged(sev),
                ),
              const Spacer(),
              Text('${filtered.length} events',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
        // Event list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No events to display.',
                      style: TextStyle(color: AppTheme.textMuted)))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final e = filtered[filtered.length - 1 - i]; // newest first
                    return _EventRow(event: e);
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'critical' => AppTheme.error,
      'warning' => AppTheme.warning,
      'info' => AppTheme.info,
      _ => AppTheme.textSecondary,
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : AppTheme.border),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              color: isSelected ? color : AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final SystemEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = switch (event.severity) {
      'critical' => AppTheme.error,
      'warning' => AppTheme.warning,
      _ => AppTheme.info,
    };
    final icon = switch (event.severity) {
      'critical' => Icons.error_outline,
      'warning' => Icons.warning_amber_outlined,
      _ => Icons.info_outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(event.eventType,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(event.severity.toUpperCase(),
                        style: TextStyle(
                            color: color, fontSize: 9, letterSpacing: 0.5)),
                  ),
                ]),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(event.description,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatTime(event.timestamp),
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  String _formatTime(double ts) {
    try {
      final dt =
          DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toStringAsFixed(2);
    }
  }
}

class _AlertsRcaTab extends StatelessWidget {
  final EngineProvider provider;
  const _AlertsRcaTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final alert = provider.currentState?.alert;

    if (alert == null || alert.totalFired == 0) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, size: 48, color: AppTheme.accent),
          const SizedBox(height: 12),
          Text('No alerts have been fired.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text('The system is operating within normal parameters.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      );
    }

    final rca = alert.lastRootCause;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert summary card
          _AlertSummaryCard(alert: alert),
          const SizedBox(height: 16),
          // RCA card
          if (rca != null)
            _RcaDetailCard(rca: rca, message: alert.lastMessage ?? ''),
        ],
      ),
    );
  }
}

class _AlertSummaryCard extends StatelessWidget {
  final AlertInfo alert;
  const _AlertSummaryCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.notifications_active, size: 16, color: AppTheme.error),
              const SizedBox(width: 8),
              Text('Alert Summary',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]),
            const Divider(color: AppTheme.border, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AlertStat(
                    'Total Fired', '${alert.totalFired}', AppTheme.error),
                _AlertStat('Consecutive High', '${alert.consecutiveHigh}',
                    AppTheme.warning),
                _AlertStat('Cooldown', alert.inCooldown ? 'Active' : 'Inactive',
                    alert.inCooldown ? AppTheme.info : AppTheme.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AlertStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w700)),
      ]);
}

class _RcaDetailCard extends StatelessWidget {
  final RootCauseAnalysis rca;
  final String message;
  const _RcaDetailCard({required this.rca, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.biotech_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('Root Cause Analysis',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                    'Confidence: ${(rca.confidenceScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const Divider(color: AppTheme.border, height: 20),
            // Alert message
            if (message.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border(left: BorderSide(color: AppTheme.error, width: 3)),
                ),
                child: Text(message,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5)),
              ),
              const SizedBox(height: 16),
            ],
            // Summary
            Text('Summary',
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(rca.summary,
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            // Detail grid
            ResponsiveRowColumn(
              spacing: 12,
              useIntrinsicHeight: false,
              children: [
                Expanded(
                  child: _RcaField(
                    icon: Icons.hardware_outlined,
                    label: 'Primary Bottleneck',
                    value: rca.primaryBottleneck.toUpperCase(),
                    color: AppTheme.error,
                  ),
                ),
                if (rca.suspectProcess != null)
                  Expanded(
                    child: _RcaField(
                      icon: Icons.memory,
                      label: 'Suspect Process',
                      value:
                          '${rca.suspectProcess!['name']} (PID: ${rca.suspectProcess!['pid']})',
                      color: AppTheme.warning,
                    ),
                  ),
                if (rca.triggerEvent != null)
                  Expanded(
                    child: _RcaField(
                      icon: Icons.bolt_outlined,
                      label: 'Trigger Event',
                      value: rca.triggerEvent!['event_type'],
                      color: AppTheme.info,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RcaField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _RcaField(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
