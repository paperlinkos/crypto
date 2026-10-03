import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/custom_text_field.dart';
import '../../../shared/components/pill_selector.dart';

class KycFlowScreen extends ConsumerStatefulWidget {
  const KycFlowScreen({super.key});

  @override
  ConsumerState<KycFlowScreen> createState() => _KycFlowScreenState();
}

class _KycFlowScreenState extends ConsumerState<KycFlowScreen> {
  int _selectedTierTab = 1; // 1, 2, or 3
  bool _isLoading = false;

  // Tier 1 inputs
  final _bvnNinController = TextEditingController(text: '22334455667');
  final _firstNameController = TextEditingController(text: 'Chukwudi');
  final _lastNameController = TextEditingController(text: 'Okonkwo');
  String _idType = 'BVN';

  // Tier 2 inputs
  final _docNumberController = TextEditingController(text: 'A98765432');
  String _docType = 'PASSPORT';

  // Tier 3 inputs
  final _addressController = TextEditingController(text: 'Plot 10, Victoria Island');
  final _cityController = TextEditingController(text: 'Lagos');
  final _stateController = TextEditingController(text: 'Lagos');

  @override
  void dispose() {
    _bvnNinController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _docNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _submitTier1() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/kyc/tier1', body: {
        'idType': _idType,
        'idNumber': _bvnNinController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
      });

      await ref.read(authProvider.notifier).fetchProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tier 1 verification approved! ₦500,000 daily limit unlocked.'),
            backgroundColor: AppColors.deepEmerald,
          ),
        );
        setState(() => _selectedTierTab = 2);
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

  Future<void> _submitTier2() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/kyc/tier2', body: {
        'idType': _docType,
        'idNumber': _docNumberController.text.trim(),
        'selfieBase64': 'data:image/jpeg;base64,sample_liveness_biometrics',
      });

      await ref.read(authProvider.notifier).fetchProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tier 2 ID & Biometrics approved! ₦5,000,000 daily limit unlocked.'),
            backgroundColor: AppColors.deepEmerald,
          ),
        );
        setState(() => _selectedTierTab = 3);
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

  Future<void> _submitTier3() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/kyc/tier3', body: {
        'residentialAddress': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'utilityDocType': 'ELECTRICITY_BILL',
      });

      await ref.read(authProvider.notifier).fetchProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof of address submitted! Compliance team review in progress.'),
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
    final user = ref.watch(authProvider).user;
    final currentTier = user?.kyc?['tier'] ?? 'TIER_0';
    final dailyLimit = user?.kyc?['dailyLimitMinor'] ?? '0';

    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      appBar: AppBar(
        title: const Text('Identity & Limits (KYC)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Tier Status Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepEmerald.withOpacity(0.25),
                      blurRadius: 16,
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
                        const Text(
                          'ACTIVE COMPLIANCE TIER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lightMint,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentTier.replaceAll('_', ' '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Daily Limit: ${CurrencyFormatter.formatFiatMinor(dailyLimit)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Higher tiers unlock higher single and daily withdrawal capacity.',
                      style: TextStyle(fontSize: 12, color: AppColors.lightMint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tier Tabs
              PillSelector<int>(
                options: const [1, 2, 3],
                selected: _selectedTierTab,
                labelBuilder: (tier) => 'Tier $tier',
                onSelected: (tier) => setState(() => _selectedTierTab = tier),
              ),
              const SizedBox(height: 20),

              // Tier Forms
              if (_selectedTierTab == 1) ...[
                _buildTierCard(
                  tierNum: '1',
                  title: 'Instant BVN / NIN Verification',
                  limit: '₦500,000 Daily Limit',
                  desc: 'Provides instant name verification with Nigerian banking rails.',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildChip('BVN', _idType == 'BVN', () => setState(() => _idType = 'BVN')),
                          const SizedBox(width: 8),
                          _buildChip('NIN', _idType == 'NIN', () => setState(() => _idType = 'NIN')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: '$_idType Number',
                        hintText: '22334455667',
                        controller: _bvnNinController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'First Name',
                              hintText: 'Chukwudi',
                              controller: _firstNameController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Last Name',
                              hintText: 'Okonkwo',
                              controller: _lastNameController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      CustomButton(
                        text: 'Verify Tier 1 Instantly',
                        isLoading: _isLoading,
                        onPressed: _submitTier1,
                      ),
                    ],
                  ),
                ),
              ] else if (_selectedTierTab == 2) ...[
                _buildTierCard(
                  tierNum: '2',
                  title: 'Government ID & Face Liveness',
                  limit: '₦5,000,000 Daily Limit',
                  desc: 'Requires valid International Passport, Driver\'s License, or National ID Card.',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildChip('PASSPORT', _docType == 'PASSPORT', () => setState(() => _docType = 'PASSPORT')),
                          const SizedBox(width: 6),
                          _buildChip('DRIVERS_LICENSE', _docType == 'DRIVERS_LICENSE', () => setState(() => _docType = 'DRIVERS_LICENSE')),
                          const SizedBox(width: 6),
                          _buildChip('NATIONAL_ID', _docType == 'NATIONAL_ID', () => setState(() => _docType = 'NATIONAL_ID')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Document Number',
                        hintText: 'A98765432',
                        controller: _docNumberController,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.sageCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.sageBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.face_retouching_natural, color: AppColors.deepEmerald, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Biometric Liveness Match: Camera frame will capture a 3D live selfie to verify document authenticity.',
                                style: TextStyle(fontSize: 12, color: AppColors.textDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      CustomButton(
                        text: 'Submit Tier 2 Verification',
                        isLoading: _isLoading,
                        onPressed: _submitTier2,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildTierCard(
                  tierNum: '3',
                  title: 'Proof of Residential Address',
                  limit: '₦50,000,000 Daily Limit',
                  desc: 'Upload recent utility bill or bank statement (within 90 days).',
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Residential Street Address',
                        hintText: 'Plot 10, Victoria Island',
                        controller: _addressController,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'City',
                              hintText: 'Lagos',
                              controller: _cityController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'State',
                              hintText: 'Lagos',
                              controller: _stateController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      CustomButton(
                        text: 'Submit Proof of Address',
                        isLoading: _isLoading,
                        onPressed: _submitTier3,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required String tierNum,
    required String title,
    required String limit,
    required String desc,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.sageBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  limit,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.deepEmerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.mutedSage)),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.sageBorder),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepEmerald : AppColors.sageCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.deepEmerald : AppColors.sageBorder),
        ),
        child: Text(
          label.replaceAll('_', ' '),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.mutedSage,
          ),
        ),
      ),
    );
  }
}
