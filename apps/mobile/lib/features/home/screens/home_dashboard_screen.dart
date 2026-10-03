import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rates_provider.dart';
import '../../../providers/wallets_provider.dart';
import '../../../shared/components/status_badge.dart';
import '../../../shared/layout/app_scaffold.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  String _activeFiat = 'NGN';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).fetchProfile();
      ref.read(ratesProvider.notifier).fetchRates(fiat: _activeFiat);
      ref.read(walletsProvider.notifier).fetchRecentDeposits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final ratesState = ref.watch(ratesProvider);
    final walletsState = ref.watch(walletsProvider);

    final user = authState.user;
    final kycTier = user?.kyc?['tier'] ?? 'TIER_1';
    final dailyLimitMinor = user?.kyc?['dailyLimitMinor'] ?? '50000000';

    return AppScaffold(
      currentIndex: 0,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(authProvider.notifier).fetchProfile(),
              ref.read(ratesProvider.notifier).fetchRates(fiat: _activeFiat),
              ref.read(walletsProvider.notifier).fetchRecentDeposits(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar: Greeting & KYC Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.deepEmerald,
                          child: Text(
                            user?.email != null && user!.email!.isNotEmpty
                                ? user.email![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppColors.electricMint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.email?.split('@').first ?? 'Off-Ramp User',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Auto-Payout: ${user?.autoPayout == true ? 'ON' : 'OFF'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedSage,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lightMint,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.jade.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: AppColors.deepEmerald, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            kycTier.replaceAll('_', ' '),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Main Balance Card (Emerald Gradient)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepEmerald.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
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
                            'ESTIMATED FIAT PORTFOLIO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightMint,
                              letterSpacing: 0.6,
                            ),
                          ),
                          // Currency Selector
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: DropdownButton<String>(
                              value: _activeFiat,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                              dropdownColor: AppColors.deepEmerald,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'NGN', child: Text('NGN (₦)')),
                                DropdownMenuItem(value: 'GHS', child: Text('GHS (₵)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _activeFiat = val);
                                  ref.read(ratesProvider.notifier).fetchRates(fiat: val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeFiat == 'NGN' ? '₦0.00' : '₵0.00',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.electricMint, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Daily Limit: ${CurrencyFormatter.formatFiatMinor(dailyLimitMinor, currency: _activeFiat)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Action Pill Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.qr_code_2,
                        title: 'Deposit Crypto',
                        onTap: () => context.go('/deposit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.calculate_outlined,
                        title: 'Live Quote',
                        onTap: () => context.go('/calculator'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.account_balance_outlined,
                        title: 'Bank Accounts',
                        onTap: () => context.go('/deposit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Live Market Rates Ticker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Locked Rates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.lightMint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: AppColors.jade, size: 8),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Rates List Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: Column(
                    children: ratesState.rates.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Loading market rates...',
                                style: TextStyle(fontSize: 13, color: AppColors.mutedSage),
                              ),
                            )
                          ]
                        : ratesState.rates.map((rate) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.sageCard,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          rate.asset == 'USDT' ? '₮' : (rate.asset == 'BTC' ? '₿' : '\$'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: AppColors.deepEmerald,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rate.asset,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          Text(
                                            'Spread: ${rate.spreadPercent}%',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.mutedSage,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    CurrencyFormatter.formatRate(rate.effectiveRate, fiat: _activeFiat, asset: rate.asset),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Deposits / Activity Feed
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                if (walletsState.recentDeposits.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.sageBorder),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.inbox_outlined, color: AppColors.mutedSage, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'No recent deposits yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedSage,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...walletsState.recentDeposits.map((dep) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.lightMint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_downward,
                                  color: AppColors.deepEmerald,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '+${CurrencyFormatter.formatCryptoMinor(dep.amountMinor, dep.asset)} ${dep.asset}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    '${dep.confirmations}/${dep.requiredConfirmations} confirms',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mutedSage,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          StatusBadge(status: dep.status),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.sageBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.sageCard,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.deepEmerald, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
