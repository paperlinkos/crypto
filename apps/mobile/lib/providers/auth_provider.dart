import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});

class UserProfile {
  final String id;
  final String? email;
  final String? phoneNumber;
  final String country;
  final String status;
  final bool isTwoFactorEnabled;
  final bool autoPayout;
  final bool isPinSet;
  final Map<String, dynamic>? kyc;

  UserProfile({
    required this.id,
    this.email,
    this.phoneNumber,
    required this.country,
    required this.status,
    required this.isTwoFactorEnabled,
    required this.autoPayout,
    required this.isPinSet,
    this.kyc,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      country: json['country'] ?? 'NG',
      status: json['status'] ?? 'ACTIVE',
      isTwoFactorEnabled: json['isTwoFactorEnabled'] ?? false,
      autoPayout: json['autoPayout'] ?? true,
      isPinSet: json['isPinSet'] ?? false,
      kyc: json['kyc'] is Map<String, dynamic> ? json['kyc'] : null,
    );
  }
}

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final UserProfile? user;
  final String? pendingOtpRecipient;
  final String? sandboxOtpCode; // For instant testing transparency

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.user,
    this.pendingOtpRecipient,
    this.sandboxOtpCode,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    UserProfile? user,
    String? pendingOtpRecipient,
    String? sandboxOtpCode,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
      pendingOtpRecipient: pendingOtpRecipient ?? this.pendingOtpRecipient,
      sandboxOtpCode: sandboxOtpCode ?? this.sandboxOtpCode,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final SecureStorageService _storage;

  AuthNotifier(this._apiClient, this._storage) : super(AuthState()) {
    checkInitialAuth();
  }

  Future<void> checkInitialAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final profileRes = await _apiClient.get('/auth/me');
        final profile = UserProfile.fromJson(profileRes);
        state = state.copyWith(
          isAuthenticated: true,
          user: profile,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isAuthenticated: false, isLoading: false);
      }
    } catch (_) {
      await _storage.clearTokens();
      state = state.copyWith(isAuthenticated: false, isLoading: false);
    }
  }

  Future<bool> requestOtp(String recipient, {String purpose = 'SIGNUP'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiClient.post(
        '/auth/otp/request',
        body: {'recipient': recipient, 'purpose': purpose},
        requiresAuth: false,
      );

      state = state.copyWith(
        isLoading: false,
        pendingOtpRecipient: recipient,
        sandboxOtpCode: res['sandboxCode']?.toString(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signup({
    required String recipient,
    required String code,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiClient.post(
        '/auth/signup',
        body: {
          'recipient': recipient,
          'code': code,
          'password': password,
        },
        requiresAuth: false,
      );

      final accessToken = res['accessToken'];
      final refreshToken = res['refreshToken'];
      await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

      final userProfile = UserProfile.fromJson(res['user']);
      state = state.copyWith(
        isAuthenticated: true,
        user: userProfile,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiClient.post(
        '/auth/login',
        body: {
          'identifier': identifier,
          'password': password,
        },
        requiresAuth: false,
      );

      final accessToken = res['accessToken'];
      final refreshToken = res['refreshToken'];
      await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

      final userProfile = UserProfile.fromJson(res['user']);
      state = state.copyWith(
        isAuthenticated: true,
        user: userProfile,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> setPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiClient.post('/auth/pin/set', body: {'pin': pin});
      await _storage.setPinConfigured(true);
      await fetchProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final res = await _apiClient.get('/auth/me');
      final profile = UserProfile.fromJson(res);
      state = state.copyWith(user: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {}
    await _storage.clearTokens();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(apiClient, storage);
});
