import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/custom_text_field.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _isLoading = false;
  List<dynamic> _devices = [];

  // 2FA modal state
  String? _totpSecret;
  String? _totpQrUrl;
  final _totpCodeController = TextEditingController();

  // Change PIN modal state
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  @override
  void dispose() {
    _totpCodeController.dispose();
    _oldPinController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get('/auth/devices');
      if (res is List && mounted) {
        setState(() => _devices = res);
      }
    } catch (_) {}
  }

  Future<void> _generate2fa() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.post('/auth/2fa/generate');
      setState(() {
        _totpSecret = res['secret'];
        _totpQrUrl = res['otpAuthUrl'];
      });
      _show2faModal();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate 2FA: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _show2faModal() {
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
                'Setup Two-Factor Authentication (2FA)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan this QR code in Google Authenticator or enter the secret key.',
                style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 16),
              if (_totpQrUrl != null) ...[
                Center(
                  child: QrImageView(
                    data: _totpQrUrl!,
                    version: QrVersions.auto,
                    size: 140,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Secret: $_totpSecret',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              CustomTextField(
                label: 'Enter 6-Digit Authenticator Code',
                hintText: '123456',
                controller: _totpCodeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 18),
              CustomButton(
                text: 'Enable 2FA Protection',
                onPressed: () async {
                  try {
                    final apiClient = ref.read(apiClientProvider);
                    await apiClient.post('/auth/2fa/enable', body: {
                      'code': _totpCodeController.text.trim(),
                    });
                    await ref.read(authProvider.notifier).fetchProfile();
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('2FA enabled successfully!'), backgroundColor: AppColors.deepEmerald),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('2FA verification failed: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePinModal() {
    _oldPinController.clear();
    _newPinController.clear();
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
                'Change Transaction PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Current 4-Digit PIN',
                hintText: '••••',
                controller: _oldPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'New 4-Digit PIN',
                hintText: '••••',
                controller: _newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Update PIN',
                onPressed: () async {
                  try {
                    final apiClient = ref.read(apiClientProvider);
                    await apiClient.post('/auth/pin/change', body: {
                      'oldPin': _oldPinController.text.trim(),
                      'newPin': _newPinController.text.trim(),
                    });
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN updated successfully!'), backgroundColor: AppColors.deepEmerald),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update PIN: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      appBar: AppBar(
        title: const Text('Security & Profile'),
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
              // User Account Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.sageBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.deepEmerald,
                      child: Text(
                        user?.email != null && user!.email!.isNotEmpty ? user.email![0].toUpperCase() : 'U',
                        style: const TextStyle(color: AppColors.electricMint, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.email ?? 'user@offramp.test',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'KYC Tier: ${user?.kyc?['tier'] ?? 'TIER_1'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.deepEmerald, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const Text(
                'Security Credentials',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 10),

              // 2FA Item
              _buildSettingItem(
                icon: Icons.phonelink_lock,
                title: 'Two-Factor Authentication (2FA)',
                subtitle: user?.isTwoFactorEnabled == true ? 'Active (Google Authenticator)' : 'Disabled',
                trailing: user?.isTwoFactorEnabled == true
                    ? const Icon(Icons.check_circle, color: AppColors.jade, size: 20)
                    : CustomButton(
                        text: 'Enable',
                        variant: ButtonVariant.dark,
                        height: 34,
                        width: 76,
                        onPressed: _generate2fa,
                      ),
              ),
              const SizedBox(height: 10),

              // Change PIN Item
              _buildSettingItem(
                icon: Icons.pin_outlined,
                title: '4-Digit Transaction PIN',
                subtitle: 'Protects off-ramp withdrawals to your bank.',
                trailing: CustomButton(
                  text: 'Change',
                  variant: ButtonVariant.outline,
                  height: 34,
                  width: 76,
                  onPressed: _showChangePinModal,
                ),
              ),
              const SizedBox(height: 22),

              const Text(
                'Active Device Sessions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 10),

              // Devices List
              if (_devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: const Text('1 Active Session (Current Device)', style: TextStyle(fontSize: 13, color: AppColors.mutedSage)),
                )
              else
                ..._devices.map((d) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.sageBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.devices, color: AppColors.deepEmerald, size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['deviceFingerprint'] ?? 'Mobile Device', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('IP: ${d['ipAddress'] ?? '127.0.0.1'}', style: const TextStyle(fontSize: 11, color: AppColors.mutedSage)),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.verified_user, color: AppColors.jade, size: 18),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // Sign out action
              CustomButton(
                text: 'Sign Out',
                variant: ButtonVariant.dark,
                icon: Icons.logout,
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) context.go('/');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sageBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.deepEmerald, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.mutedSage)),
                ],
              ),
            ],
          ),
          trailing,
        ],
      ),
    );
  }
}
