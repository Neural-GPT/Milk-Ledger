import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/logout_fab.dart';
import 'dashboard_tab.dart';
import 'customers_tab.dart';
import 'analysis_tab.dart';
import 'milkman_log_tab.dart';

class MilkmanHomeShell extends StatefulWidget {
  const MilkmanHomeShell({super.key});

  @override
  State<MilkmanHomeShell> createState() => _MilkmanHomeShellState();
}

class _MilkmanHomeShellState extends State<MilkmanHomeShell> {
  int _index = 0;
  final _customersKey = GlobalKey<CustomersTabState>();
  final _analysisKey = GlobalKey<AnalysisTabState>();
  final _logKey = GlobalKey<MilkmanLogTabState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardTab(onCustomersChanged: () => _customersKey.currentState?.reload()),
      CustomersTab(key: _customersKey),
      AnalysisTab(key: _analysisKey),
      MilkmanLogTab(key: _logKey),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      floatingActionButton: const LogoutFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          if (i == 1) _customersKey.currentState?.reload();
          if (i == 2) _analysisKey.currentState?.reload();
          if (i == 3) _logKey.currentState?.reload();
        },
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Analysis'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'My Log'),
        ],
      ),
    );
  }
}
