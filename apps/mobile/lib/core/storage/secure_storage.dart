import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _storage.write(key: AppConstants.tokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userProfileKey);
  }

  Future<void> setPinConfigured(bool isSet) async {
    await _storage.write(key: AppConstants.pinSetKey, value: isSet.toString());
  }

  Future<bool> isPinConfigured() async {
    final val = await _storage.read(key: AppConstants.pinSetKey);
    return val == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: AppConstants.biometricsEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: AppConstants.biometricsEnabledKey);
    return val == 'true';
  }
}
