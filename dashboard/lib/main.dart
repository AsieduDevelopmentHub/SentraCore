import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentracore_dashboard/providers/engine_provider.dart';
import 'package:sentracore_dashboard/screens/dashboard_screen.dart';
import 'package:sentracore_dashboard/theme/app_theme.dart';

void main() {
  runApp(const SentraCoreApp());
}

class SentraCoreApp extends StatelessWidget {
  const SentraCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EngineProvider()..connect(),
      child: MaterialApp(
        title: 'SentraCore Dashboard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );
  }
}
