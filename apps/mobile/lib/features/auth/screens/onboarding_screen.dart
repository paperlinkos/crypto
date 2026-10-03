import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../shared/components/custom_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Brand Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.jade.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: AppColors.deepEmerald, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'INSTANT FIAT SETTLEMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepEmerald,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Headline
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    height: 1.15,
                    letterSpacing: -0.6,
                  ),
                  children: [
                    TextSpan(text: 'Crypto to Naira,\nDirect to '),
                    TextSpan(
                      text: 'Your Bank.',
                      style: TextStyle(
                        color: AppColors.deepEmerald,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Receive USDT, USDC, or BTC at your personal address. Get paid in NGN or GHS in under 60 seconds at live locked rates.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.mutedSage,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              // Visual Feature Card Stack
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.darkCardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.darkCardBorder),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      icon: Icons.lock_clock_outlined,
                      title: '15-Minute Rate Lock',
                      desc: 'Guaranteed rate from the first blockchain ping.',
                    ),
                    const Divider(color: AppColors.darkCardBorder, height: 24),
                    _buildFeatureRow(
                      icon: Icons.account_balance_outlined,
                      title: 'Direct Bank Settlement',
                      desc: 'Instant payout to any Nigerian or Ghanaian bank account.',
                    ),
                    const Divider(color: AppColors.darkCardBorder, height: 24),
                    _buildFeatureRow(
                      icon: Icons.shield_outlined,
                      title: 'Institutional Security',
                      desc: 'Double-entry ledger with automated fraud safeguards.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // CTA Action
              CustomButton(
                text: 'Get Started',
                variant: ButtonVariant.primary,
                icon: Icons.arrow_forward,
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.emeraldSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.electricMint, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: AppColors.mutedSubtext,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
