import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/app_colors.dart';
import '../../../config/constants.dart';
import '../../../providers/wallets_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/pill_selector.dart';
import '../../../shared/components/progress_ring.dart';
import '../../../shared/layout/app_scaffold.dart';

class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  String _depositType = 'Crypto'; // 'Crypto' or 'Naira Bank Transfer'
  String _selectedAsset = AppConstants.usdt;
  String _selectedNetwork = AppConstants.tronTrc20;

  // Rate Lock Simulation State for Demo
  bool _isRateLocked = false;
  int _rateLockSeconds = 900; // 15 mins (900s)
  final String _lockedRateStr = '₦1,520.00';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAddress();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    await ref.read(walletsProvider.notifier).assignWallet(_selectedAsset, _selectedNetwork);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppColors.deepEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _triggerSimulatedNairaDeposit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.electricMint, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Incoming Bank Transfer Detected! ₦50,000.00 credited to your NGN Balance.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.obsidianForest,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _triggerSimulatedCryptoLock() {
    _timer?.cancel();
    setState(() {
      _isRateLocked = true;
      _rateLockSeconds = 899;
    });

    // Start ticking countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_rateLockSeconds > 0) {
        setState(() {
          _rateLockSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isRateLocked = false;
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.electricMint, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '⚡ 1st Confirmation Detected! 15-Minute Rate Locked at ₦1,520.00/USDT (0% Slippage).',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepEmerald,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
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
                'Deposit Funds',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Receive Crypto or Naira (NGN) directly into your account.',
                style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 18),

              // Segmented Toggle: Crypto vs Naira Bank Transfer
              PillSelector<String>(
                options: const ['Crypto', 'Naira Bank Transfer'],
                selected: _depositType,
                labelBuilder: (type) => type == 'Crypto' ? 'Receive Crypto' : 'Naira Bank Deposit',
                onSelected: (val) {
                  setState(() {
                    _depositType = val;
                  });
                },
              ),
              const SizedBox(height: 20),

              // DISPLAY 1: NAIRA BANK TRANSFER DEPOSIT
              if (_depositType == 'Naira Bank Transfer') ...[
                _buildNairaDepositCard(),
              ]
              // DISPLAY 2: CRYPTO DEPOSIT (USDT, USDC, BTC)
              else ...[
                _buildCryptoDepositCard(walletsState, wallet),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // NAIRA BANK TRANSFER VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildNairaDepositCard() {
    const bankName = 'Moniepoint Microfinance Bank';
    const accountNumber = '9012345678';
    const accountName = 'OFFRAMP / Chinedu Okafor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dedicated Bank Account Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepEmerald, Color(0xFF073A27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepEmerald.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.electricMint.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: AppColors.electricMint, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'DEDICATED NGN ACCOUNT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.electricMint,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Instant Credit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB5D4C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bank Name
              const Text(
                'BANK NAME',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8DBCA8), letterSpacing: 0.6),
              ),
              const SizedBox(height: 2),
              const Text(
                bankName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),

              const SizedBox(height: 14),

              // Account Number with Copy
              const Text(
                'ACCOUNT NUMBER',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8DBCA8), letterSpacing: 0.6),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    accountNumber,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.electricMint,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.electricMint, size: 22),
                    onPressed: () => _copyToClipboard(accountNumber, 'Account number'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Account Name
              const Text(
                'ACCOUNT NAME',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8DBCA8), letterSpacing: 0.6),
              ),
              const SizedBox(height: 2),
              const Text(
                accountName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Transfer Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sageBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.deepEmerald, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'How Naira Deposits Work',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInstructionStep('1', 'Transfer NGN from any Nigerian bank app (GTBank, Zenith, Access, Kuda, OPay, Moniepoint).'),
              const SizedBox(height: 6),
              _buildInstructionStep('2', 'Deposits are credited automatically to your Naira balance within 30 seconds.'),
              const SizedBox(height: 6),
              _buildInstructionStep('3', 'Use your NGN balance to instantly buy USDT/USDC/BTC or cash out to any bank.'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Interactive Demo Tool: Simulate Incoming Bank Deposit
        CustomButton(
          text: '⚡ Demo: Simulate Incoming ₦50k Bank Deposit',
          variant: ButtonVariant.primary,
          icon: Icons.flash_on_rounded,
          onPressed: _triggerSimulatedNairaDeposit,
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.lightMint,
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.deepEmerald),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedSage, height: 1.35),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CRYPTO DEPOSIT VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCryptoDepositCard(WalletsState walletsState, AssignedWallet? wallet) {
    final mins = _rateLockSeconds ~/ 60;
    final secs = _rateLockSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final progress = _rateLockSeconds / 900.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                color: Colors.black.withValues(alpha: 0.03),
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
                        onPressed: () => _copyToClipboard(wallet.address, 'Wallet address'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Copy CTA Button
                CustomButton(
                  text: 'Copy Wallet Address',
                  variant: ButtonVariant.primary,
                  icon: Icons.copy,
                  height: 48,
                  onPressed: () => _copyToClipboard(wallet.address, 'Wallet address'),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 4. ACTIVE RATE LOCK CARD (OR GUARANTEE NOTICE)
        if (_isRateLocked) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.darkCardGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.jade, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.jade.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.electricMint.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_rounded, color: AppColors.electricMint, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'RATE LOCK ACTIVE',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.electricMint),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'GUARANTEED RATE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.mutedSubtext, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_lockedRateStr / $_selectedAsset',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '✓ 1st Confirmation Received • 0% Slippage Protected',
                        style: TextStyle(fontSize: 11, color: AppColors.electricMint),
                      ),
                    ],
                  ),
                ),
                ProgressRing(
                  progress: progress,
                  centerText: timeStr,
                  subText: 'REMAINING',
                  size: 76,
                  strokeWidth: 5,
                  progressColor: AppColors.electricMint,
                  backgroundColor: AppColors.darkCardBorder,
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightMint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.jade.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.deepEmerald, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '15-Minute Guaranteed Rate Lock',
                        style: TextStyle(
                          color: AppColors.deepEmerald,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.deepEmerald,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '0% SLIPPAGE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.electricMint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The moment 1 blockchain confirmation is detected on-chain, your exchange rate is locked for 15 minutes. No market volatility risk.',
                  style: TextStyle(
                    color: AppColors.deepEmerald,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Demo Trigger for Rate Lock Demonstration
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _triggerSimulatedCryptoLock,
                    icon: const Icon(Icons.lock_clock_rounded, color: AppColors.deepEmerald, size: 16),
                    label: const Text(
                      '⚡ Demo: Trigger 15-Min Rate Lock Countdown',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepEmerald),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.jade, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
