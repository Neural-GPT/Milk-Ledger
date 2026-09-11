import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'core/api_client.dart';
import 'features/auth/login_screen.dart';
import 'features/milkman/milkman_home_shell.dart';
import 'features/customer/customer_home_shell.dart';
import 'features/admin/admin_home_shell.dart';

void main() {
  runApp(const ProviderScope(child: MilkApp()));
}

class MilkApp extends StatelessWidget {
  const MilkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milk Ledger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _StartupRouter(),
      routes: {
        '/': (_) => const LoginScreen(),
        '/milkman': (_) => const MilkmanHomeShell(),
        '/customer': (_) => const CustomerHomeShell(),
        '/admin': (_) => const AdminHomeShell(),
      },
    );
  }
}

/// If a token + role are already saved on-device, jump straight to that
/// dashboard - this works even with no network, since it's just reading
/// local storage. A stale/expired token still gets caught the moment the
/// dashboard tries to fetch data (each screen's own error handling covers
/// that); this only decides which screen to open first.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final token = await ApiClient.instance.getToken();
    final role = await ApiClient.instance.getRole();

    if (!mounted) return;

    if (token != null && role != null) {
      final route = switch (role) {
        'MILKMAN' => '/milkman',
        'CUSTOMER' => '/customer',
        'ADMIN' => '/admin',
        _ => '/',
      };
      Navigator.of(context).pushReplacementNamed(route);
    } else {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
