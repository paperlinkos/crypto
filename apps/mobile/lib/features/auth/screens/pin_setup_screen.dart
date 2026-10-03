import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../providers/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _enableBiometrics = true;

  void _handleNumberPress(String number) {
    if (!_isConfirming) {
      if (_pin.length < 4) {
        setState(() => _pin += number);
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), () {
            setState(() => _isConfirming = true);
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += number);
        if (_confirmPin.length == 4) {
          _verifyAndSave();
        }
      }
    }
  }

  void _handleDelete() {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin != _confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Please try again.')),
      );
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    final success = await ref.read(authProvider.notifier).setPin(_pin);
    if (success && mounted) {
      if (_enableBiometrics) {
        final storage = ref.read(secureStorageProvider);
        await storage.setBiometricsEnabled(true);
      }
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLength = _isConfirming ? _confirmPin.length : _pin.length;

    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Security Shield Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.jade.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.deepEmerald,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                _isConfirming ? 'Confirm Transaction PIN' : 'Set 4-Digit Security PIN',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Re-enter your 4-digit PIN to verify.'
                    : 'This PIN authorizes off-ramp withdrawals to your bank.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.mutedSage),
              ),
              const SizedBox(height: 32),

              // 4 PIN Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < activeLength;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isFilled ? AppColors.deepEmerald : AppColors.lightSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFilled ? AppColors.deepEmerald : AppColors.sageBorder,
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: AppColors.deepEmerald.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Biometric toggle
              if (!_isConfirming) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint, color: AppColors.deepEmerald, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Enable Face ID / Biometrics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Switch(
                        value: _enableBiometrics,
                        activeColor: AppColors.deepEmerald,
                        activeTrackColor: AppColors.lightMint,
                        onChanged: (val) => setState(() => _enableBiometrics = val),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Numeric Keypad
              _buildKeypad(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'delete'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 60);
              }
              if (key == 'delete') {
                return SizedBox(
                  width: 72,
                  height: 60,
                  child: IconButton(
                    icon: const Icon(Icons.backspace_outlined, color: AppColors.mutedSage),
                    onPressed: _handleDelete,
                  ),
                );
              }

              return InkWell(
                onTap: () => _handleNumberPress(key),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 72,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.sageBorder.withOpacity(0.6)),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
