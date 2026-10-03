import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  // API Base URL (Default to local backend API on port 4000)
  static String get defaultApiBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://127.0.0.1:4000/api/v1';
  }

  // Supported Assets
  static const String usdt = 'USDT';
  static const String usdc = 'USDC';
  static const String btc = 'BTC';

  // Networks
  static const String tronTrc20 = 'TRON_TRC20';
  static const String ethErc20 = 'ETHEREUM_ERC20';
  static const String bscBep20 = 'BSC_BEP20';
  static const String btcMainnet = 'BITCOIN_MAINNET';

  // Supported Fiat Currencies
  static const String ngn = 'NGN';
  static const String ghs = 'GHS';

  // Storage Keys
  static const String tokenKey = 'offramp_jwt_token';
  static const String refreshTokenKey = 'offramp_refresh_token';
  static const String userProfileKey = 'offramp_user_profile';
  static const String pinSetKey = 'offramp_pin_set';
  static const String biometricsEnabledKey = 'offramp_biometrics_enabled';
  static const String apiBaseUrlKey = 'offramp_api_url';
}
