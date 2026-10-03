import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/custom_text_field.dart';
import 'bank_accounts_screen.dart';

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _amountController = TextEditingController(text: '50000');
  final _narrationController = TextEditingController(text: 'Crypto Off-Ramp Settlement');
  final _pinController = TextEditingController();

  List<BankAccountItem> _bankAccounts = [];
  BankAccountItem? _selectedAccount;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _narrationController.dispose();
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

  Future<void> _handleWithdraw() async {
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

    // Show 4-Digit PIN Modal
    _showPinModal();
  }

  void _showPinModal() {
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
              const Text(
                'Authorize Bank Withdrawal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your 4-digit PIN to disburse ${CurrencyFormatter.formatFiat(double.tryParse(_amountController.text) ?? 0.0)} to ${_selectedAccount?.bankName}.',
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
                text: 'Confirm & Transfer',
                isLoading: _isProcessing,
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeWithdrawal();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeWithdrawal() async {
    final amountMajor = double.tryParse(_amountController.text.trim()) ?? 0.0;
    // Major to minor kobo (50000 NGN = 5000000 kobo)
    final amountMinor = (amountMajor * 100).toInt().toString();

    setState(() => _isProcessing = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final idempotencyKey = 'WITHDRAW-${DateTime.now().millisecondsSinceEpoch}';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      appBar: AppBar(
        title: const Text('Withdraw to Bank'),
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
                      'Off-Ramp Bank Transfer',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Disburse local fiat to your verified bank account in under 60 seconds.',
                      style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
                    ),
                    const SizedBox(height: 22),

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
                      label: 'Payout Amount (NGN ₦)',
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
                      text: 'Authorize Withdrawal',
                      icon: Icons.arrow_forward,
                      variant: ButtonVariant.primary,
                      onPressed: _handleWithdraw,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
