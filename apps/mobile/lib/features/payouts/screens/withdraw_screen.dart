import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/custom_text_field.dart';
import '../../../shared/components/pill_selector.dart';
import 'bank_accounts_screen.dart';

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  // Mode: 'BANK' or 'CRYPTO'
  String _withdrawMode = 'BANK';

  // Bank Form State
  final _amountController = TextEditingController(text: '50000');
  final _narrationController = TextEditingController(text: 'Crypto Off-Ramp Settlement');
  List<BankAccountItem> _bankAccounts = [];
  BankAccountItem? _selectedAccount;

  // Crypto Form State
  String _cryptoAsset = 'USDT';
  String _cryptoNetwork = 'TRON_TRC20';
  final _cryptoAddressController = TextEditingController();
  final _cryptoAmountController = TextEditingController(text: '100');

  // Shared PIN controller
  final _pinController = TextEditingController();

  bool _isLoading = true;
  bool _isProcessing = false;

  final Map<String, List<String>> _assetNetworks = {
    'USDT': ['TRON_TRC20', 'ETHEREUM_ERC20', 'BINANCE_BEP20'],
    'BTC': ['BITCOIN'],
    'USDC': ['ETHEREUM_ERC20', 'POLYGON', 'BINANCE_BEP20'],
  };

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _narrationController.dispose();
    _cryptoAddressController.dispose();
    _cryptoAmountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadBankAccounts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get('/payouts/bank-accounts');
      if (res is List) {
        _bankAccounts = res.map((a) => BankAccountItem.fromJson(a)).toList();
        if (_bankAccounts.isNotEmpty) {
          _selectedAccount = _bankAccounts.firstWhere(
            (a) => a.isDefault,
            orElse: () => _bankAccounts.first,
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleBankWithdraw() {
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or link a bank account first.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payout amount.')),
      );
      return;
    }

    _showPinModal(isCrypto: false);
  }

  void _handleCryptoWithdraw() {
    final address = _cryptoAddressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid recipient crypto address.')),
      );
      return;
    }

    final amount = double.tryParse(_cryptoAmountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid crypto withdrawal amount.')),
      );
      return;
    }

    _showPinModal(isCrypto: true);
  }

  void _showPinModal({required bool isCrypto}) {
    _pinController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCrypto ? 'Authorize Crypto Send' : 'Authorize Bank Withdrawal',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                isCrypto
                    ? 'Enter your 4-digit PIN to send ${_cryptoAmountController.text} $_cryptoAsset to ${_cryptoAddressController.text.length > 12 ? "${_cryptoAddressController.text.substring(0, 8)}...${_cryptoAddressController.text.substring(_cryptoAddressController.text.length - 4)}" : _cryptoAddressController.text}.'
                    : 'Enter your 4-digit PIN to disburse ${CurrencyFormatter.formatFiat(double.tryParse(_amountController.text) ?? 0.0)} to ${_selectedAccount?.bankName}.',
                style: const TextStyle(fontSize: 13, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: '4-Digit Transaction PIN',
                hintText: '••••',
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.deepEmerald, size: 20),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: isCrypto ? 'Confirm & Send Crypto' : 'Confirm & Transfer',
                isLoading: _isProcessing,
                onPressed: () {
                  Navigator.pop(ctx);
                  if (isCrypto) {
                    _executeCryptoWithdrawal();
                  } else {
                    _executeBankWithdrawal();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeBankWithdrawal() async {
    final amountMajor = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final amountMinor = (amountMajor * 100).toInt().toString();

    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final idempotencyKey = 'WITHDRAW-BANK-${DateTime.now().millisecondsSinceEpoch}';

      final res = await apiClient.post('/payouts/withdraw', body: {
        'bankAccountId': _selectedAccount!.id,
        'amountMinor': amountMinor,
        'pin': _pinController.text.trim(),
        'idempotencyKey': idempotencyKey,
        'narration': _narrationController.text.trim(),
        'currency': _selectedAccount!.currency,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.jade, size: 28),
                SizedBox(width: 10),
                Text('Withdrawal Sent!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              'Payout of ${CurrencyFormatter.formatFiat(amountMajor)} dispatched to ${_selectedAccount?.bankName} (${_selectedAccount?.accountNumber}). Ref: ${res['providerRef']}',
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepEmerald)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeCryptoWithdrawal() async {
    final amountMajor = double.tryParse(_cryptoAmountController.text.trim()) ?? 0.0;
    // For USDT/USDC (6 decimals = 1,000,000), for BTC (8 decimals = 100,000,000)
    final multiplier = _cryptoAsset == 'BTC' ? 100000000 : 1000000;
    final amountMinor = (amountMajor * multiplier).toInt().toString();

    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final idempotencyKey = 'WITHDRAW-CRYPTO-${DateTime.now().millisecondsSinceEpoch}';

      final res = await apiClient.post('/wallets/withdraw', body: {
        'asset': _cryptoAsset,
        'network': _cryptoNetwork,
        'destinationAddress': _cryptoAddressController.text.trim(),
        'amountMinor': amountMinor,
        'pin': _pinController.text.trim(),
        'idempotencyKey': idempotencyKey,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.jade, size: 28),
                SizedBox(width: 10),
                Text('Crypto Dispatched!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully broadcasted $amountMajor $_cryptoAsset on ${_cryptoNetwork.replaceAll('_', ' ')}.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.sageCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transaction Hash:', style: TextStyle(fontSize: 11, color: AppColors.mutedSage)),
                      const SizedBox(height: 4),
                      Text(
                        res['txHash'] ?? '0x...',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.deepEmerald),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepEmerald)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crypto Send Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.deepEmerald))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Payout Method',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Disburse local fiat to your bank account or send crypto to an external wallet.',
                      style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
                    ),
                    const SizedBox(height: 18),

                    // Top Segmented Pill Toggle: Bank vs Crypto
                    PillSelector<String>(
                      options: const ['BANK', 'CRYPTO'],
                      selected: _withdrawMode,
                      labelBuilder: (m) => m == 'BANK' ? '🏦 Bank (Fiat)' : '🪙 Crypto Wallet',
                      onSelected: (m) => setState(() => _withdrawMode = m),
                    ),
                    const SizedBox(height: 22),

                    if (_withdrawMode == 'BANK')
                      _buildBankWithdrawForm()
                    else
                      _buildCryptoWithdrawForm(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBankWithdrawForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Destination Account Selector
        const Text(
          'Destination Bank Account',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedSage),
        ),
        const SizedBox(height: 8),
        if (_bankAccounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.sageBorder),
            ),
            child: Column(
              children: [
                const Text('No verified bank account linked yet.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                CustomButton(
                  text: '+ Add Bank Account',
                  variant: ButtonVariant.dark,
                  height: 44,
                  onPressed: () => context.push('/bank-accounts'),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.jade, width: 1.5),
            ),
            child: DropdownButton<BankAccountItem>(
              isExpanded: true,
              underline: const SizedBox(),
              value: _selectedAccount,
              items: _bankAccounts.map((acc) {
                return DropdownMenuItem<BankAccountItem>(
                  value: acc,
                  child: Text(
                    '${acc.bankName} • ${acc.accountNumber} (${acc.verifiedName})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedAccount = val),
            ),
          ),
        const SizedBox(height: 20),

        // Amount Input
        CustomTextField(
          label: 'Payout Amount (NGN ₦ / GHS ₵)',
          hintText: '50000',
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: const Icon(Icons.attach_money, color: AppColors.deepEmerald, size: 20),
        ),
        const SizedBox(height: 14),

        // Narration Input
        CustomTextField(
          label: 'Transfer Narration / Description',
          hintText: 'e.g. Crypto Off-Ramp Payout',
          controller: _narrationController,
        ),
        const SizedBox(height: 24),

        // Fee summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sageCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sageBorder),
          ),
          child: const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transfer Fee:', style: TextStyle(fontSize: 12, color: AppColors.mutedSage)),
                  Text('₦53.75 (NIBSS Clearing)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated Arrival:', style: TextStyle(fontSize: 12, color: AppColors.mutedSage)),
                  Text('Instant (< 60 secs)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepEmerald)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Withdraw Button
        CustomButton(
          text: 'Authorize Bank Withdrawal',
          icon: Icons.arrow_forward,
          variant: ButtonVariant.primary,
          onPressed: _handleBankWithdraw,
        ),
      ],
    );
  }

  Widget _buildCryptoWithdrawForm() {
    final availableNetworks = _assetNetworks[_cryptoAsset] ?? ['TRON_TRC20'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Select Asset
        const Text(
          'Select Crypto Asset',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedSage),
        ),
        const SizedBox(height: 8),
        PillSelector<String>(
          options: const ['USDT', 'BTC', 'USDC'],
          selected: _cryptoAsset,
          labelBuilder: (a) => a,
          onSelected: (a) {
            setState(() {
              _cryptoAsset = a;
              _cryptoNetwork = (_assetNetworks[a] ?? ['TRON_TRC20']).first;
            });
          },
        ),
        const SizedBox(height: 18),

        // Select Network
        const Text(
          'Destination Blockchain Network',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedSage),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sageBorder),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            value: _cryptoNetwork,
            items: availableNetworks.map((net) {
              return DropdownMenuItem<String>(
                value: net,
                child: Text(
                  net.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _cryptoNetwork = val);
            },
          ),
        ),
        const SizedBox(height: 18),

        // Destination Crypto Address
        CustomTextField(
          label: 'Recipient Wallet Address',
          hintText: _cryptoNetwork == 'TRON_TRC20' ? 'e.g. TYDzsYUEpvnYmQk4zGP9sWWcTEd2MiAtW6' : 'e.g. 0x... or bc1q...',
          controller: _cryptoAddressController,
          suffixIcon: IconButton(
            icon: const Icon(Icons.content_paste, color: AppColors.deepEmerald, size: 20),
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              if (data?.text != null) {
                _cryptoAddressController.text = data!.text!.trim();
              }
            },
          ),
        ),
        const SizedBox(height: 14),

        // Amount Input
        CustomTextField(
          label: 'Withdrawal Amount ($_cryptoAsset)',
          hintText: '100.00',
          controller: _cryptoAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: const Icon(Icons.toll_outlined, color: AppColors.deepEmerald, size: 20),
        ),
        const SizedBox(height: 24),

        // Network Fee summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sageCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sageBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Network Gas:', style: TextStyle(fontSize: 12, color: AppColors.mutedSage)),
                  Text(
                    _cryptoAsset == 'BTC' ? '0.0001 BTC' : '1.00 $_cryptoAsset',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('On-Chain Confirmation:', style: TextStyle(fontSize: 12, color: AppColors.mutedSage)),
                  Text('~1 - 3 Minutes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepEmerald)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Crypto Withdraw Button
        CustomButton(
          text: 'Send $_cryptoAsset On-Chain',
          icon: Icons.send_rounded,
          variant: ButtonVariant.primary,
          onPressed: _handleCryptoWithdraw,
        ),
      ],
    );
  }
}
