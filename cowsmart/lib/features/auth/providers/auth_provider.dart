import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:cowsmart/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Current Authentication State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;
  final String? token;
  final Map<String, dynamic>? user;
  final bool isNewUser;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
    this.token,
    this.user,
    this.isNewUser = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    String? token,
    Map<String, dynamic>? user,
    bool? isNewUser,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
      token: token ?? this.token,
      user: user ?? this.user,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final ApiClient _api;

  @override
  AuthState build() {
    _api = ref.watch(apiClientProvider);
    // Try to load persisted token
    Future.microtask(() => _checkPersistedToken());
    return AuthState();
  }

  Future<void> _checkPersistedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');

    if (token != null) {
      _api.setToken(token);
      Map<String, dynamic>? userData;
      if (userJson != null) {
        userData = json.decode(userJson);
      }
      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        user: userData,
        isNewUser: false,
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      final token = data['access_token'];
      final userData = data['user'];

      _api.setToken(token);

      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_data', json.encode(userData));

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: token,
        user: userData,
        isNewUser: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.post(
        '/register',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      );

      final data = response.data;
      final token = data['access_token'];
      final userData = data['user'];

      _api.setToken(token);

      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_data', json.encode(userData));

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: token,
        user: userData,
        isNewUser: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } finally {
      _api.setToken(null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      state = AuthState();
    }
  }

  Future<void> refreshUser() async {
    try {
      final response = await _api.get('/user');
      final userData = response.data as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', json.encode(userData));

      state = state.copyWith(user: userData);
    } catch (e) {
      // Silently fail refresh
    }
  }
}

// Global provider for accessing auth state
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
