import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/device_id.dart';

enum AuthStatus { idle, loading, loggedIn, error }

class AuthState {
  final AuthStatus status;
  final String? role; // MILKMAN, CUSTOMER, or ADMIN
  final String? error;

  AuthState({this.status = AuthStatus.idle, this.role, this.error});
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(AuthState());

  final Dio _dio = ApiClient.instance.dio;

  Future<void> _completeLogin(Map<String, dynamic> data) async {
    await ApiClient.instance.saveToken(data['access_token']);
    await ApiClient.instance.saveRole(data['role']);
    state = AuthState(status: AuthStatus.loggedIn, role: data['role']);
  }

  Future<void> milkmanLogin(String phoneNumber, String name) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      final res = await _dio.post('/auth/milkman-login', data: {
        'phone_number': phoneNumber,
        'name': name,
      });
      await _completeLogin(res.data);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _errorMessage(e));
    }
  }

  /// The login screen only shows one "Username" + "Phone number" form now.
  /// A milkman's real credentials are name + phone, so we try that first.
  /// If no milkman account matches that phone number at all (404), the
  /// same two fields are retried as an admin's username + numeric password -
  /// this is how the admin logs in without a separate tab.
  Future<void> unifiedMilkmanOrAdminLogin(String username, String phoneOrPassword) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      final res = await _dio.post('/auth/milkman-login', data: {
        'phone_number': phoneOrPassword,
        'name': username,
      });
      await _completeLogin(res.data);
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        // A milkman account exists for that number but the name didn't
        // match - that's a real error, don't silently try admin instead.
        state = AuthState(status: AuthStatus.error, error: _errorMessage(e));
        return;
      }
    }

    try {
      final res = await _dio.post('/auth/admin-login', data: {
        'username': username,
        'password': phoneOrPassword,
      });
      await _completeLogin(res.data);
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
      await _completeLogin(res.data);
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
      await _completeLogin(res.data);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _errorMessage(e));
    }
  }

  Future<void> logout() async {
    await ApiClient.instance.clearToken();
    await ApiClient.instance.clearRole();
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
