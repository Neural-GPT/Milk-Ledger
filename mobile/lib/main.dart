import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'core/connectivity_banner.dart';
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
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/milkman': (_) => const MilkmanHomeShell(),
        '/customer': (_) => const CustomerHomeShell(),
        '/admin': (_) => const AdminHomeShell(),
      },
      builder: (context, child) => ConnectivityBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
