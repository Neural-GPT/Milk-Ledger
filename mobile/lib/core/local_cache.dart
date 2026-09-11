import 'package:shared_preferences/shared_preferences.dart';

/// Stores the last-known-good response for read endpoints, so the app
/// still shows something useful when there's no network - not a full
/// offline-write queue, just "don't show a blank screen when offline."
class LocalCache {
  static Future<void> set(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_$key', value);
    await prefs.setString('cache_${key}_at', DateTime.now().toIso8601String());
  }

  static Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cache_$key');
  }

  static Future<DateTime?> lastUpdated(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString('cache_${key}_at');
    return iso != null ? DateTime.tryParse(iso) : null;
  }
}
