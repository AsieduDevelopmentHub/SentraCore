import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/navigation/dashboard_navigation.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/screens/overview_screen.dart';
import 'package:sentracore_dashboard/screens/performance_screen.dart';
import 'package:sentracore_dashboard/screens/processes_screen.dart';
import 'package:sentracore_dashboard/screens/diagnostics_screen.dart';
import 'package:sentracore_dashboard/screens/settings_screen.dart';
import 'package:sentracore_dashboard/screens/logbook_screen.dart';
import 'package:sentracore_dashboard/screens/storage_screen.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';
import 'package:sentracore_dashboard/widgets/connection_banner.dart';
import 'package:sentracore_dashboard/providers/settings_provider.dart';

/// Root shell with persistent navigation rail and page switching.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _navExpanded = false;

  @override
  void initState() {
    super.initState();
    DashboardNavigation.selectMainTab = (i) {
      if (!mounted) return;
      setState(() => _selectedIndex = i.clamp(0, 6));
    };
  }

  @override
  void dispose() {
    DashboardNavigation.selectMainTab = null;
    super.dispose();
  }

  static const _pages = [
    OverviewScreen(),
    PerformanceScreen(),
    ProcessesScreen(),
    LogbookScreen(),
    DiagnosticsScreen(),
    StorageScreen(),
    SettingsScreen(),
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
                  expanded: _navExpanded,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  onToggleExpanded: () =>
                      setState(() => _navExpanded = !_navExpanded),
                  provider: provider,
                ),
                // ── Vertical Divider ──
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
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
  final bool expanded;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onToggleExpanded;
  final EngineProvider provider;

  const _SentraNavRail({
    required this.expanded,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onToggleExpanded,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final stability = provider.stability;
    final stabilityColor = stability != null
        ? AppTheme.stabilityColor(stability.state)
        : AppTheme.textMutedFor(context);
    final stabilityScore = stability?.score.toStringAsFixed(0) ?? '--';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: expanded ? 232 : 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo — flat frame, no gradient (design.md calm tone)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              color: AppTheme.surfaceLightFor(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/brandmark.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.shield_outlined,
                  color: AppTheme.textMutedFor(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: expanded ? 'Collapse' : 'Expand',
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    expanded ? Icons.chevron_left_rounded : Icons.menu_rounded,
                    color: AppTheme.textMutedFor(context),
                    size: 22,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 2),
                  Text(
                    'SentraCore',
                    style: TextStyle(
                      color: AppTheme.textPrimaryFor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Stability mini-score
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: stabilityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stabilityColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  stabilityScore,
                  style: TextStyle(
                    color: stabilityColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'STABILITY',
                  style: TextStyle(
                    color: stabilityColor.withValues(alpha: 0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: Theme.of(context).dividerColor),
          ),
          const SizedBox(height: 8),
          // Nav items
          _navItem(context, 0, Icons.grid_view_outlined,
              Icons.grid_view_rounded, 'Overview'),
          _navItem(context, 1, Icons.analytics_outlined,
              Icons.analytics_rounded, 'Performance'),
          _navItem(context, 2, Icons.layers_outlined, Icons.layers_rounded,
              'Processes'),
          _navItem(
              context, 3, Icons.book_outlined, Icons.book_rounded, 'Logbook'),
          _navItem(context, 4, Icons.troubleshoot_outlined,
              Icons.troubleshoot_rounded, 'Diagnostics'),
          _navItem(context, 5, Icons.cleaning_services_outlined,
              Icons.cleaning_services_rounded, 'Storage'),
          _navItem(context, 6, Icons.settings_outlined, Icons.settings_rounded,
              'Settings'),
          const Spacer(),
          // Theme Toggle
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => IconButton.filledTonal(
              tooltip: 'Toggle light / dark',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.surfaceLightFor(context),
                foregroundColor: AppTheme.primary,
              ),
              onPressed: () => settings.toggleTheme(),
              icon: Icon(
                settings.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Connection status dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: provider.connected ? AppTheme.success : AppTheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon,
      IconData activeIcon, String label) {
    final isSelected = selectedIndex == index;
    final content = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onDestinationSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin:
            EdgeInsets.symmetric(vertical: 4, horizontal: expanded ? 10 : 8),
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: expanded ? 12 : 0,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.textMutedFor(context),
              size: 22,
            ),
            if (expanded) ...[
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.textPrimaryFor(context)
                      : AppTheme.textSecondaryFor(context),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return expanded
        ? content
        : Tooltip(message: label, preferBelow: false, child: content);
  }
}
