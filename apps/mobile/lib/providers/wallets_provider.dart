import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import 'auth_provider.dart';

class AssignedWallet {
  final String id;
  final String asset;
  final String network;
  final String address;
  final String? qrCodeDataUrl;

  AssignedWallet({
    required this.id,
    required this.asset,
    required this.network,
    required this.address,
    this.qrCodeDataUrl,
  });

  factory AssignedWallet.fromJson(Map<String, dynamic> json) {
    return AssignedWallet(
      id: json['id'] ?? '',
      asset: json['asset'] ?? 'USDT',
      network: json['network'] ?? 'TRON_TRC20',
      address: json['address'] ?? '',
      qrCodeDataUrl: json['qrCodeDataUrl'],
    );
  }
}

class DepositTransaction {
  final String id;
  final String txHash;
  final String asset;
  final String network;
  final String amountMinor;
  final int confirmations;
  final int requiredConfirmations;
  final String status;
  final String? lockedRate;
  final DateTime detectedAt;

  DepositTransaction({
    required this.id,
    required this.txHash,
    required this.asset,
    required this.network,
    required this.amountMinor,
    required this.confirmations,
    required this.requiredConfirmations,
    required this.status,
    this.lockedRate,
    required this.detectedAt,
  });

  factory DepositTransaction.fromJson(Map<String, dynamic> json) {
    return DepositTransaction(
      id: json['id'] ?? '',
      txHash: json['txHash'] ?? '',
      asset: json['asset'] ?? 'USDT',
      network: json['network'] ?? 'TRON_TRC20',
      amountMinor: json['amountMinor']?.toString() ?? '0',
      confirmations: json['confirmations'] ?? 0,
      requiredConfirmations: json['requiredConfirmations'] ?? 3,
      status: json['status'] ?? 'DETECTED',
      lockedRate: json['lockedRate']?.toString(),
      detectedAt: DateTime.tryParse(json['detectedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class WalletsState {
  final List<AssignedWallet> wallets;
  final AssignedWallet? selectedWallet;
  final List<DepositTransaction> recentDeposits;
  final bool isLoading;
  final String? error;

  WalletsState({
    this.wallets = const [],
    this.selectedWallet,
    this.recentDeposits = const [],
    this.isLoading = false,
    this.error,
  });

  WalletsState copyWith({
    List<AssignedWallet>? wallets,
    AssignedWallet? selectedWallet,
    List<DepositTransaction>? recentDeposits,
    bool? isLoading,
    String? error,
  }) {
    return WalletsState(
      wallets: wallets ?? this.wallets,
      selectedWallet: selectedWallet ?? this.selectedWallet,
      recentDeposits: recentDeposits ?? this.recentDeposits,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WalletsNotifier extends StateNotifier<WalletsState> {
  final ApiClient _apiClient;

  WalletsNotifier(this._apiClient) : super(WalletsState());

  Future<void> fetchWallets() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiClient.get('/wallets');
      if (res is List) {
        final items = res.map((w) => AssignedWallet.fromJson(w as Map<String, dynamic>)).toList();
        state = state.copyWith(
          wallets: items,
          selectedWallet: items.isNotEmpty ? items.first : null,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<AssignedWallet?> assignWallet(String asset, String network) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiClient.post(
        '/wallets/assign',
        body: {'asset': asset, 'network': network},
      );

      final wallet = AssignedWallet.fromJson(res);
      final updatedList = List<AssignedWallet>.from(state.wallets);
      final index = updatedList.indexWhere((w) => w.asset == asset && w.network == network);
      if (index >= 0) {
        updatedList[index] = wallet;
      } else {
        updatedList.add(wallet);
      }

      state = state.copyWith(
        wallets: updatedList,
        selectedWallet: wallet,
        isLoading: false,
      );
      return wallet;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> fetchRecentDeposits() async {
    try {
      final res = await _apiClient.get('/wallets/deposits');
      if (res is List) {
        final deposits = res.map((d) => DepositTransaction.fromJson(d as Map<String, dynamic>)).toList();
        state = state.copyWith(recentDeposits: deposits);
      }
    } catch (_) {}
  }
}

final walletsProvider = StateNotifierProvider<WalletsNotifier, WalletsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WalletsNotifier(apiClient);
});
