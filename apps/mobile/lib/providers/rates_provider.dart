import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import 'auth_provider.dart';

class RateItem {
  final String asset;
  final String fiat;
  final double baseSpotRate;
  final double spreadPercent;
  final double effectiveRate;
  final String source;
  final bool isStale;

  RateItem({
    required this.asset,
    required this.fiat,
    required this.baseSpotRate,
    required this.spreadPercent,
    required this.effectiveRate,
    required this.source,
    required this.isStale,
  });

  factory RateItem.fromJson(Map<String, dynamic> json) {
    return RateItem(
      asset: json['asset'] ?? 'USDT',
      fiat: json['fiat'] ?? 'NGN',
      baseSpotRate: (json['baseSpotRate'] as num?)?.toDouble() ?? 0.0,
      spreadPercent: (json['spreadPercent'] as num?)?.toDouble() ?? 0.0,
      effectiveRate: (json['effectiveRate'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] ?? '',
      isStale: json['isStale'] ?? false,
    );
  }
}

class OffRampQuote {
  final String quoteId;
  final String asset;
  final String fiat;
  final String cryptoAmount;
  final String baseSpotRate;
  final String spreadPercent;
  final String effectiveRate;
  final String grossFiatAmount;
  final String spreadFeeFiat;
  final String netPayoutFiat;
  final String netPayoutMinor;
  final int validForSeconds;
  final DateTime expiresAt;

  OffRampQuote({
    required this.quoteId,
    required this.asset,
    required this.fiat,
    required this.cryptoAmount,
    required this.baseSpotRate,
    required this.spreadPercent,
    required this.effectiveRate,
    required this.grossFiatAmount,
    required this.spreadFeeFiat,
    required this.netPayoutFiat,
    required this.netPayoutMinor,
    required this.validForSeconds,
    required this.expiresAt,
  });

  factory OffRampQuote.fromJson(Map<String, dynamic> json) {
    return OffRampQuote(
      quoteId: json['quoteId'] ?? '',
      asset: json['asset'] ?? 'USDT',
      fiat: json['fiat'] ?? 'NGN',
      cryptoAmount: json['cryptoAmount']?.toString() ?? '0',
      baseSpotRate: json['baseSpotRate']?.toString() ?? '0',
      spreadPercent: json['spreadPercent']?.toString() ?? '1.5%',
      effectiveRate: json['effectiveRate']?.toString() ?? '0',
      grossFiatAmount: json['grossFiatAmount']?.toString() ?? '0',
      spreadFeeFiat: json['spreadFeeFiat']?.toString() ?? '0',
      netPayoutFiat: json['netPayoutFiat']?.toString() ?? '0',
      netPayoutMinor: json['netPayoutMinor']?.toString() ?? '0',
      validForSeconds: json['validForSeconds'] ?? 900,
      expiresAt: DateTime.tryParse(json['expiresAt'] ?? '') ?? DateTime.now().add(const Duration(minutes: 15)),
    );
  }
}

class RatesState {
  final List<RateItem> rates;
  final OffRampQuote? activeQuote;
  final String selectedAsset;
  final String selectedFiat;
  final int quoteSecondsRemaining;
  final bool isLoading;
  final String? error;

  RatesState({
    this.rates = const [],
    this.activeQuote,
    this.selectedAsset = 'USDT',
    this.selectedFiat = 'NGN',
    this.quoteSecondsRemaining = 0,
    this.isLoading = false,
    this.error,
  });

  RatesState copyWith({
    List<RateItem>? rates,
    OffRampQuote? activeQuote,
    String? selectedAsset,
    String? selectedFiat,
    int? quoteSecondsRemaining,
    bool? isLoading,
    String? error,
  }) {
    return RatesState(
      rates: rates ?? this.rates,
      activeQuote: activeQuote ?? this.activeQuote,
      selectedAsset: selectedAsset ?? this.selectedAsset,
      selectedFiat: selectedFiat ?? this.selectedFiat,
      quoteSecondsRemaining: quoteSecondsRemaining ?? this.quoteSecondsRemaining,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RatesNotifier extends StateNotifier<RatesState> {
  final ApiClient _apiClient;
  Timer? _countdownTimer;

  RatesNotifier(this._apiClient) : super(RatesState()) {
    fetchRates();
  }

  Future<void> fetchRates({String? fiat}) async {
    final currency = fiat ?? state.selectedFiat;
    state = state.copyWith(isLoading: true, error: null, selectedFiat: currency);
    try {
      final res = await _apiClient.get('/rates', queryParams: {'fiat': currency}, requiresAuth: false);
      if (res is List) {
        final items = res.map((r) => RateItem.fromJson(r as Map<String, dynamic>)).toList();
        state = state.copyWith(rates: items, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSelectedAsset(String asset) {
    state = state.copyWith(selectedAsset: asset);
  }

  void setSelectedFiat(String fiat) {
    state = state.copyWith(selectedFiat: fiat);
    fetchRates(fiat: fiat);
  }

  Future<OffRampQuote?> calculateQuote({
    required String asset,
    required double amount,
    String? fiat,
  }) async {
    final currency = fiat ?? state.selectedFiat;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiClient.get(
        '/rates/quote',
        queryParams: {
          'asset': asset,
          'amount': amount.toString(),
          'fiat': currency,
        },
        requiresAuth: false,
      );

      final quote = OffRampQuote.fromJson(res);
      state = state.copyWith(
        activeQuote: quote,
        quoteSecondsRemaining: quote.validForSeconds,
        isLoading: false,
      );

      _startTimer(quote.validForSeconds);
      return quote;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  void _startTimer(int totalSeconds) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.quoteSecondsRemaining > 0) {
        state = state.copyWith(quoteSecondsRemaining: state.quoteSecondsRemaining - 1);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

final ratesProvider = StateNotifierProvider<RatesNotifier, RatesState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RatesNotifier(apiClient);
});
