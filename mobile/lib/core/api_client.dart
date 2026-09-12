import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_cache.dart';

/// Result of a cached-GET call - tells the caller whether it's looking
/// at a fresh network response or a fallback from local storage, so
/// the UI can show an "offline - showing saved data" banner.
class CachedResult {
  final dynamic data;
  final bool fromCache;
  CachedResult(this.data, this.fromCache);
}

/// Single source of truth for talking to the backend.
/// The Flutter app NEVER touches PostgreSQL directly - everything
/// goes through this HTTPS client, per the roadmap's #29 principle.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();

  // Using `adb reverse tcp:8000 tcp:8000` over USB, the phone's
  // localhost:8000 forwards straight to the PC's backend. Once deployed
  // to Render, point this at that HTTPS URL instead.
  static const String baseUrl = 'https://milk-ledger-1gxx.onrender.com';

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  Future<void> saveToken(String token) => _storage.write(key: 'access_token', value: token);
  Future<void> clearToken() => _storage.delete(key: 'access_token');
  Future<String?> getToken() => _storage.read(key: 'access_token');

  // Persisted alongside the token so the app can route straight to the
  // right dashboard on next launch without needing a network call first -
  // this is what makes "already logged in" work offline.
  Future<void> saveRole(String role) => _storage.write(key: 'user_role', value: role);
  Future<String?> getRole() => _storage.read(key: 'user_role');
  Future<void> clearRole() => _storage.delete(key: 'user_role');

  bool _isConnectivityError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.unknown;
  }

  /// GET that caches successful responses and falls back to the last
  /// cached copy if the network is unreachable. Rethrows normal API
  /// errors (4xx/5xx) unchanged - only connectivity failures fall back.
  Future<CachedResult> cachedGet(String path, {Map<String, dynamic>? queryParameters}) async {
    final cacheKey = '$path?${queryParameters ?? {}}';
    try {
      final res = await _dio.get(path, queryParameters: queryParameters);
      await LocalCache.set(cacheKey, jsonEncode(res.data));
      return CachedResult(res.data, false);
    } on DioException catch (e) {
      if (_isConnectivityError(e)) {
        final cached = await LocalCache.get(cacheKey);
        if (cached != null) {
          return CachedResult(jsonDecode(cached), true);
        }
      }
      rethrow;
    }
  }
}
