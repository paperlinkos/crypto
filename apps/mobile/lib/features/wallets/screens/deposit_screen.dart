import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/app_colors.dart';
import '../../../config/constants.dart';
import '../../../providers/wallets_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/pill_selector.dart';
import '../../../shared/layout/app_scaffold.dart';

class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  String _selectedAsset = AppConstants.usdt;
  String _selectedNetwork = AppConstants.tronTrc20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAddress();
    });
  }

  Future<void> _loadAddress() async {
    await ref.read(walletsProvider.notifier).assignWallet(_selectedAsset, _selectedNetwork);
  }

  void _copyToClipboard(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied to clipboard!'),
        backgroundColor: AppColors.deepEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletsState = ref.watch(walletsProvider);
    final wallet = walletsState.selectedWallet;

    return AppScaffold(
      currentIndex: 1,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Receive Crypto',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Send crypto to your personal address for instant conversion & payout.',
                style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 20),

              // 1. Asset Selector (USDT, USDC, BTC)
              const Text(
                'Select Asset',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 8),
              PillSelector<String>(
                options: const [AppConstants.usdt, AppConstants.usdc, AppConstants.btc],
                selected: _selectedAsset,
                labelBuilder: (asset) => asset,
                onSelected: (asset) {
                  setState(() {
                    _selectedAsset = asset;
                    if (asset == AppConstants.btc) {
                      _selectedNetwork = AppConstants.btcMainnet;
                    } else if (_selectedNetwork == AppConstants.btcMainnet) {
                      _selectedNetwork = AppConstants.tronTrc20;
                    }
                  });
                  _loadAddress();
                },
              ),
              const SizedBox(height: 16),

              // 2. Network Selector
              const Text(
                'Select Network',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 8),
              if (_selectedAsset == AppConstants.btc)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: const Text('Bitcoin Mainnet (1 Confirmation)', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              else
                Row(
                  children: [
                    _buildNetworkChip(AppConstants.tronTrc20, 'TRON (TRC20)'),
                    const SizedBox(width: 8),
                    _buildNetworkChip(AppConstants.ethErc20, 'Ethereum (ERC20)'),
                    const SizedBox(width: 8),
                    _buildNetworkChip(AppConstants.bscBep20, 'BNB (BEP20)'),
                  ],
                ),
              const SizedBox(height: 24),

              // 3. QR Code & Address Display Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.sageBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (walletsState.isLoading || wallet == null)
                      const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.deepEmerald),
                        ),
                      )
                    else ...[
                      // High-Contrast QR Code
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.sageBorder),
                        ),
                        child: QrImageView(
                          data: wallet.address,
                          version: QrVersions.auto,
                          size: 180.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.obsidianForest,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.obsidianForest,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Crypto Address String
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.sageCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                wallet.address,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: AppColors.deepEmerald, size: 20),
                              onPressed: () => _copyToClipboard(wallet.address),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Copy CTA Button
                      CustomButton(
                        text: 'Copy Address',
                        variant: ButtonVariant.primary,
                        icon: Icons.copy,
                        height: 48,
                        onPressed: () => _copyToClipboard(wallet.address),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Rate Lock Guarantee Notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.jade.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt, color: AppColors.deepEmerald, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '15-Minute Guaranteed Rate Lock: As soon as 1 blockchain confirmation is detected, your fiat exchange rate is locked for 15 minutes.',
                        style: TextStyle(
                          color: AppColors.deepEmerald,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkChip(String network, String label) {
    final isSelected = _selectedNetwork == network;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedNetwork = network);
          _loadAddress();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.deepEmerald : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.deepEmerald : AppColors.sageBorder,
            ),
          ),
          child: Text(
            label.split(' ').first,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.mutedSage,
            ),
          ),
        ),
      ),
    );
  }
}
