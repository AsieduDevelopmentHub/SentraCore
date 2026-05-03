import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

/// Timeline of recent system events with severity-based coloring.
class EventTimeline extends StatelessWidget {
  final String filter;
  const EventTimeline({super.key, this.filter = ''});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();
    final q = filter.trim().toLowerCase();
    final events = q.isEmpty
        ? provider.events
        : provider.events.where((e) {
            final type = e.eventType.toLowerCase();
            final desc = e.description.toLowerCase();
            return type.contains(q) || desc.contains(q);
          }).toList();

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
                    const Icon(
                      Icons.timeline,
                      size: 16,
                      color: AppTheme.info,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Event Timeline',
                      style: TextStyle(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${events.length} events',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textMutedFor(context)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Event list
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'No events yet...',
                        style: TextStyle(
                          color: AppTheme.textMutedFor(context),
                          fontSize: 11,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: events.length.clamp(0, 30),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return _EventTile(
                          eventType: event.eventType,
                          severity: event.severity,
                          timestamp: event.timestamp,
                          details: event.details,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final String eventType;
  final String severity;
  final double timestamp;
  final Map<String, dynamic> details;

  const _EventTile({
    required this.eventType,
    required this.severity,
    required this.timestamp,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(severity);
    final icon = _eventIcon(eventType);
    final time = DateTime.fromMillisecondsSinceEpoch(
      (timestamp * 1000).toInt(),
    );
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity dot
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          _formatEventType(eventType),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimaryFor(context),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.textMutedFor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppTheme.stressCritical;
      case 'warning':
        return AppTheme.warning;
      case 'info':
      default:
        return AppTheme.info;
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'cpu_spike':
        return Icons.memory;
      case 'memory_pressure':
        return Icons.storage;
      case 'disk_spike':
        return Icons.disc_full_outlined;
      case 'process_start':
        return Icons.play_arrow;
      case 'process_stop':
        return Icons.stop;
      default:
        return Icons.info_outline;
    }
  }

  String _formatEventType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
