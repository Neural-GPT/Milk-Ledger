import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A stable per-install identifier. Doesn't need to be a "real" hardware
/// ID - just needs to stay the same across app restarts on this device,
/// which secure storage gives us for free.
class DeviceId {
  static const _storage = FlutterSecureStorage();
  static const _key = 'device_id';

  static Future<String> get() async {
    final existing = await _storage.read(key: _key);
    if (existing != null) return existing;

    final generated = _randomId();
    await _storage.write(key: _key, value: generated);
    return generated;
  }

  static String _randomId() {
    final rand = Random.secure();
    return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  }
}
