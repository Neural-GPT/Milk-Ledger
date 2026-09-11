import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/logout_fab.dart';
import 'admin_milkmen_tab.dart';
import 'admin_customers_tab.dart';
import 'admin_logs_tab.dart';

class AdminHomeShell extends StatefulWidget {
  const AdminHomeShell({super.key});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  int _index = 0;
  final _milkmenKey = GlobalKey<AdminMilkmenTabState>();
  final _customersKey = GlobalKey<AdminCustomersTabState>();
  final _logsKey = GlobalKey<AdminLogsTabState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminMilkmenTab(key: _milkmenKey),
      AdminCustomersTab(key: _customersKey),
      AdminLogsTab(key: _logsKey),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: SafeArea(child: pages[_index]),
      floatingActionButton: const LogoutFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          if (i == 0) _milkmenKey.currentState?.reload();
          if (i == 1) _customersKey.currentState?.reload();
          if (i == 2) _logsKey.currentState?.reload();
        },
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Milkmen'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Logs'),
        ],
      ),
    );
  }
}
