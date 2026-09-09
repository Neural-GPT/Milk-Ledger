import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/device_id.dart';

enum AuthStatus { idle, loading, loggedIn, error }

class AuthState {
  final AuthStatus status;
  final String? role; // MILKMAN or CUSTOMER
  final String? error;

  AuthState({this.status = AuthStatus.idle, this.role, this.error});
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(AuthState());

  final Dio _dio = ApiClient.instance.dio;

  Future<void> milkmanLogin(String phoneNumber, String name) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      final res = await _dio.post('/auth/milkman-login', data: {
        'phone_number': phoneNumber,
        'name': name,
      });
      await ApiClient.instance.saveToken(res.data['access_token']);
      state = AuthState(status: AuthStatus.loggedIn, role: res.data['role']);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _errorMessage(e));
    }
  }

  Future<void> adminLogin(String username, String password) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      final res = await _dio.post('/auth/admin-login', data: {
        'username': username,
        'password': password,
      });
      await ApiClient.instance.saveToken(res.data['access_token']);
      state = AuthState(status: AuthStatus.loggedIn, role: res.data['role']);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _errorMessage(e));
    }
  }

  Future<void> customerLogin(String phoneNumber) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      final deviceId = await DeviceId.get();
      final res = await _dio.post('/auth/customer-login', data: {
        'phone_number': phoneNumber,
        'device_id': deviceId,
      });
      await ApiClient.instance.saveToken(res.data['access_token']);
      state = AuthState(status: AuthStatus.loggedIn, role: res.data['role']);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _errorMessage(e));
    }
  }

  Future<void> logout() async {
    await ApiClient.instance.clearToken();
    state = AuthState(status: AuthStatus.idle);
  }

  String _errorMessage(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    String? detail;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      detail = d is String ? d : d.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      detail = data.trim();
    }
    if (detail != null) return detail;

    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Can\'t reach the server. Check adb reverse is running and the backend is up.';
    }
    if (status != null) return 'Server returned status $status.';
    return 'Something went wrong (${e.type}). Please try again.';
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(),
);
