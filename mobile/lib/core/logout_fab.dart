import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import '../features/auth/auth_controller.dart';

/// Pinned bottom-left (via floatingActionButtonLocation.startFloat on the
/// parent Scaffold) rather than the usual top-right AppBar spot.
class LogoutFab extends ConsumerWidget {
  const LogoutFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      heroTag: 'logout_fab',
      backgroundColor: AppTheme.surfaceLight,
      foregroundColor: AppTheme.textPrimary,
      elevation: 0,
      onPressed: () {
        ref.read(authControllerProvider.notifier).logout();
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      child: const Icon(Icons.logout),
    );
  }
}
