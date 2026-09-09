import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single source of truth for talking to the backend.
/// The Flutter app NEVER touches PostgreSQL directly - everything
/// goes through this HTTPS client, per the roadmap's #29 principle.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(baseUrl: baseUrl));
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
  // localhost:8000 forwards straight to the PC's backend. Once you deploy
  // for real, point this at your HTTPS domain instead.
  static const String baseUrl = 'http://localhost:8000';

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  Future<void> saveToken(String token) => _storage.write(key: 'access_token', value: token);
  Future<void> clearToken() => _storage.delete(key: 'access_token');
  Future<String?> getToken() => _storage.read(key: 'access_token');
}
