import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'app_theme.dart';

/// Wraps the whole app (via MaterialApp.builder) and shows a slim banner
/// at the top whenever the backend is unreachable. Pings /health every
/// 10 seconds - cheap enough to run continuously, and immediately tells
/// every screen "we're offline" without each one polling separately.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _online = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      await ApiClient.instance.dio.get('/health');
      if (mounted && !_online) setState(() => _online = true);
    } catch (_) {
      if (mounted && _online) setState(() => _online = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_online)
          Container(
            width: double.infinity,
            color: AppTheme.warning,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const SafeArea(
              bottom: false,
              child: Text(
                'Offline - showing saved data where available',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
