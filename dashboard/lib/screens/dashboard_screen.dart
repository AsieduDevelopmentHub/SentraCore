import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/screens/overview_screen.dart';
import 'package:sentracore_dashboard/screens/performance_screen.dart';
import 'package:sentracore_dashboard/screens/processes_screen.dart';
import 'package:sentracore_dashboard/screens/diagnostics_screen.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/connection_banner.dart';

/// Root shell with persistent navigation rail and page switching.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static const _pages = [
    OverviewScreen(),
    PerformanceScreen(),
    ProcessesScreen(),
    DiagnosticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EngineProvider>();

    return Scaffold(
      body: Column(
        children: [
          if (!provider.connected) const ConnectionBanner(),
          Expanded(
            child: Row(
              children: [
                // ── Left Navigation Rail ──
                _SentraNavRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  provider: provider,
                ),
                // ── Vertical Divider ──
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppTheme.border,
                ),
                // ── Page Content ──
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SentraNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final EngineProvider provider;

  const _SentraNavRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final stability = provider.stability;
    final stabilityColor = stability != null
        ? AppTheme.stabilityColor(stability.state)
        : AppTheme.textMuted;
    final stabilityScore = stability?.score.toStringAsFixed(0) ?? '--';

    return Container(
      width: 72,
      color: AppTheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo / brand mark
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              image: const DecorationImage(
                image: AssetImage('assets/brandmark.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Stability mini-score
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: stabilityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: stabilityColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text(
                  stabilityScore,
                  style: TextStyle(
                    color: stabilityColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'STA',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 8, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.border, indent: 8, endIndent: 8),
          // Nav items
          _navItem(context, 0, Icons.dashboard_outlined, Icons.dashboard,
              'Overview'),
          _navItem(context, 1, Icons.show_chart_outlined, Icons.show_chart,
              'Performance'),
          _navItem(
              context, 2, Icons.memory_outlined, Icons.memory, 'Processes'),
          _navItem(context, 3, Icons.bug_report_outlined, Icons.bug_report,
              'Diagnostics'),
          const Spacer(),
          // Connection status dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: provider.connected ? AppTheme.accent : AppTheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (provider.connected ? AppTheme.accent : AppTheme.error)
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon,
      IconData activeIcon, String label) {
    final isSelected = selectedIndex == index;
    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onDestinationSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}
