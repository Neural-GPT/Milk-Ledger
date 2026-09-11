import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import 'auth_controller.dart';

enum _LoginMode { milkman, customer }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoginMode _mode = _LoginMode.milkman;
  final _usernameController = TextEditingController();
  final _phoneOrPasswordController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.loggedIn) {
        if (next.role == 'MILKMAN') {
          Navigator.of(context).pushReplacementNamed('/milkman');
        } else if (next.role == 'CUSTOMER') {
          Navigator.of(context).pushReplacementNamed('/customer');
        } else if (next.role == 'ADMIN') {
          Navigator.of(context).pushReplacementNamed('/admin');
        }
      }
    });

    final authState = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final loading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.85),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_drink_rounded, size: 56, color: AppTheme.accent),
                const SizedBox(height: 12),
                const Text(
                  'Milk Ledger',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 32),

                // Milkman/Admin share one form now; Customer is separate (phone-only, no password).
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(child: _modeTab('Milkman / Admin', _LoginMode.milkman)),
                      Expanded(child: _modeTab('Customer', _LoginMode.customer)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_mode == _LoginMode.milkman) ...[
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(hintText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneOrPasswordController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Milkman: your registered name + phone number. Admin: your username + numeric password.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ] else ...[
                  TextField(
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your number gets linked to this device on first login.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 20),
                if (authState.error != null) ...[
                  Text(authState.error!, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () {
                          if (_mode == _LoginMode.milkman) {
                            controller.unifiedMilkmanOrAdminLogin(
                              _usernameController.text.trim(),
                              _phoneOrPasswordController.text.trim(),
                            );
                          } else {
                            controller.customerLogin(_customerPhoneController.text.trim());
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('LOG IN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, _LoginMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.black : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
