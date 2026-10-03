import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/custom_text_field.dart';

class BankAccountItem {
  final String id;
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String verifiedName;
  final String currency;
  final bool isDefault;
  final bool isVerified;

  BankAccountItem({
    required this.id,
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.verifiedName,
    required this.currency,
    required this.isDefault,
    required this.isVerified,
  });

  factory BankAccountItem.fromJson(Map<String, dynamic> json) {
    return BankAccountItem(
      id: json['id'] ?? '',
      bankCode: json['bankCode'] ?? '',
      bankName: json['bankName'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      verifiedName: json['verifiedName'] ?? '',
      currency: json['currency'] ?? 'NGN',
      isDefault: json['isDefault'] ?? false,
      isVerified: json['isVerified'] ?? true,
    );
  }
}

class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  List<BankAccountItem> _accounts = [];
  List<dynamic> _supportedBanks = [];
  bool _isLoading = true;

  // Add Account State
  bool _isAdding = false;
  String? _selectedBankCode = '058';
  final _accountNumberController = TextEditingController(text: '0123456789');
  String? _resolvedAccountName;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final [accountsRes, banksRes] = await Future.wait([
        apiClient.get('/payouts/bank-accounts'),
        apiClient.get('/payouts/banks?currency=NGN'),
      ]);

      if (accountsRes is List) {
        _accounts = accountsRes.map((a) => BankAccountItem.fromJson(a)).toList();
      }
      if (banksRes is List) {
        _supportedBanks = banksRes;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _resolveAccount() async {
    final number = _accountNumberController.text.trim();
    if (number.length != 10 || _selectedBankCode == null) return;

    setState(() => _isResolving = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.post('/payouts/resolve-account', body: {
        'accountNumber': number,
        'bankCode': _selectedBankCode,
      });
      setState(() => _resolvedAccountName = res['accountName']);
    } catch (e) {
      setState(() => _resolvedAccountName = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Name Enquiry Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _saveAccount() async {
    if (_resolvedAccountName == null) {
      await _resolveAccount();
    }
    if (_resolvedAccountName == null) return;

    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/payouts/bank-accounts', body: {
        'bankCode': _selectedBankCode,
        'accountNumber': _accountNumberController.text.trim(),
        'isDefault': _accounts.isEmpty,
        'currency': 'NGN',
      });

      setState(() => _isAdding = false);
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank account verified & saved!'),
            backgroundColor: AppColors.deepEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      appBar: AppBar(
        title: const Text('Saved Bank Accounts'),
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
                      'Destination Bank Accounts',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'All off-ramp conversions are disbursed instantly to these verified NUBAN accounts.',
                      style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
                    ),
                    const SizedBox(height: 20),

                    // Saved Accounts List
                    ..._accounts.map((acc) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: acc.isDefault ? AppColors.jade : AppColors.sageBorder,
                            width: acc.isDefault ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.lightMint,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance,
                                    color: AppColors.deepEmerald,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          acc.bankName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        if (acc.isDefault) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.deepEmerald,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'DEFAULT',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${acc.accountNumber} • ${acc.verifiedName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mutedSage,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(Icons.verified, color: AppColors.jade, size: 20),
                          ],
                        ),
                      );
                    }),

                    if (!_isAdding) ...[
                      const SizedBox(height: 12),
                      CustomButton(
                        text: '+ Link New Bank Account',
                        variant: ButtonVariant.dark,
                        onPressed: () => setState(() => _isAdding = true),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      // Add Account Form
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.sageBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Link Nigerian Bank Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Bank dropdown
                            const Text(
                              'Select Bank',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedSage),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppColors.sageCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.sageBorder),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                underline: const SizedBox(),
                                value: _selectedBankCode,
                                items: _supportedBanks.map((b) {
                                  return DropdownMenuItem<String>(
                                    value: b['code'].toString(),
                                    child: Text(
                                      b['name'].toString(),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedBankCode = val;
                                    _resolvedAccountName = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Account Number input
                            CustomTextField(
                              label: '10-Digit NUBAN Account Number',
                              hintText: '0123456789',
                              controller: _accountNumberController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) {
                                if (_accountNumberController.text.length == 10) {
                                  _resolveAccount();
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Name Enquiry Status Card
                            if (_isResolving)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepEmerald),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Resolving NUBAN name enquiry...', style: TextStyle(fontSize: 12, color: AppColors.mutedSage)),
                                  ],
                                ),
                              )
                            else if (_resolvedAccountName != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.lightMint,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.jade.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: AppColors.deepEmerald, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Verified Name: $_resolvedAccountName',
                                        style: const TextStyle(
                                          color: AppColors.deepEmerald,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 18),

                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    text: 'Cancel',
                                    variant: ButtonVariant.outline,
                                    height: 46,
                                    onPressed: () => setState(() => _isAdding = false),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomButton(
                                    text: 'Confirm & Save',
                                    variant: ButtonVariant.primary,
                                    height: 46,
                                    onPressed: _saveAccount,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
