import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import 'customer_home_tab.dart';
import 'customer_calendar_tab.dart';
import 'customer_log_tab.dart';

class CustomerHomeShell extends StatefulWidget {
  const CustomerHomeShell({super.key});

  @override
  State<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends State<CustomerHomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final _homeKey = GlobalKey<CustomerHomeTabState>();
  final _calendarKey = GlobalKey<CustomerCalendarTabState>();
  final _logKey = GlobalKey<CustomerLogTabState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForNewNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForNewNotifications();
  }

  Future<void> _checkForNewNotifications() async {
    try {
      final res = await ApiClient.instance.dio.get('/notifications/me');
      final unread = (res.data as List).where((n) => n['is_read'] == false).toList();
      // Only pop up for the newest one (most recent first from the API) so a
      // customer catching up after a while isn't hit with a stack of dialogs.
      if (unread.isNotEmpty && mounted) {
        final n = unread.first;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(n['title'] ?? ''),
            content: Text(n['message'] ?? '', style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
            ],
          ),
        );
        // Deliberately NOT marking as read here - the pill on the Home
        // tab shows the same message and stays until the person dismisses
        // it there, so the popup is just an immediate heads-up.
        _homeKey.currentState?.reload();
      }
    } catch (_) {
      // Silent - notifications are a nice-to-have, not core flow.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomerHomeTab(key: _homeKey),
      CustomerCalendarTab(key: _calendarKey),
      CustomerLogTab(key: _logKey),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          if (i == 1) _calendarKey.currentState?.reload();
          if (i == 2) _logKey.currentState?.reload();
        },
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'My Log'),
        ],
      ),
    );
  }
}
