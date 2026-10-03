import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../shared/components/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _pages = const [
    OnboardingItem(
      badge: 'INSTANT FIAT SETTLEMENT',
      badgeIcon: Icons.bolt_rounded,
      headlineFirst: 'Crypto to Naira,\nDirect to ',
      headlineAccent: 'Your Bank.',
      description:
          'Receive USDT, USDC, or BTC at your personal address. Funds are automatically converted and credited to your Nigerian or Ghanaian bank account in under 60 seconds.',
    ),
    OnboardingItem(
      badge: 'ZERO VOLATILITY RISK',
      badgeIcon: Icons.lock_clock_rounded,
      headlineFirst: '15-Minute Rate Lock.\nGuaranteed ',
      headlineAccent: 'Zero Slippage.',
      description:
          'From the moment your deposit hits the blockchain, your exchange rate is locked solid for 15 minutes. What you see is exactly what lands in your account.',
    ),
    OnboardingItem(
      badge: 'BANK-GRADE INFRASTRUCTURE',
      badgeIcon: Icons.verified_user_rounded,
      headlineFirst: 'Institutional Security.\nDouble-Entry ',
      headlineAccent: 'Ledger Built.',
      description:
          'Every kobo and satoshi is tracked in an immutable double-entry ledger with instant audit logs and automated fraud protection at every tier.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/login');
    }
  }

  void _onSkip() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand Pill + Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.lightMint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.jade.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_exchange_rounded, color: AppColors.deepEmerald, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'OFFRAMP DIRECT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.deepEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _onSkip,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedSage,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 32),
                ],
              ),
            ),

            // Page Content (Illustrations + Typography)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) {
                  setState(() {
                    _currentPage = idx;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Interactive High-Fidelity Illustration Container (Scales to fit safely)
                        Expanded(
                          flex: 12,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildIllustrationForPage(index),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.lightMint,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.jade.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(page.badgeIcon, size: 14, color: AppColors.deepEmerald),
                              const SizedBox(width: 6),
                              Text(
                                page.badge,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppColors.deepEmerald,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Main Headline
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              height: 1.18,
                              letterSpacing: -0.5,
                            ),
                            children: [
                              TextSpan(text: page.headlineFirst),
                              TextSpan(
                                text: page.headlineAccent,
                                style: const TextStyle(
                                  color: AppColors.deepEmerald,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          page.description,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.mutedSage,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Footer (Dots + Primary Action)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (idx) {
                      final isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 7,
                        width: isActive ? 28 : 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.deepEmerald : AppColors.sageBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // Action Button ("Get Started" on initial & final screen, "Continue" on page 2)
                  CustomButton(
                    text: _currentPage == 1 ? 'Continue' : 'Get Started',
                    icon: Icons.arrow_forward_rounded,
                    variant: ButtonVariant.primary,
                    onPressed: _onNext,
                  ),

                  const SizedBox(height: 10),

                  // Google Sign-In Shortcut Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        // Direct navigation into app home
                        context.go('/home');
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.sageBorder, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GoogleGLogoWidget(),
                          SizedBox(width: 8),
                          Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  ILLUSTRATION BUILDERS: Crisp, clean, layered fintech UI on White Canvas
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildIllustrationForPage(int index) {
    switch (index) {
      case 0:
        return _buildSettlementFlowIllustration();
      case 1:
        return _buildRateLockIllustration();
      case 2:
        return _buildSecurityLedgerIllustration();
      default:
        return _buildSettlementFlowIllustration();
    }
  }

  // Page 1 Illustration: Real-time Crypto Deposit -> Direct Bank Settlement
  Widget _buildSettlementFlowIllustration() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.sageBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepEmerald.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step 1: Crypto Deposit Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.porcelainSage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sageBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF26A17B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF26A17B).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '₮',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'USDT Deposit',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.check_circle_rounded, color: AppColors.jade, size: 13),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'TRC-20 • Confirmed',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedSage,
                        ),
                      ),
                    ],
                  ),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+500.00',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'USDT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedSage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Central Connector: Real-time swap badge
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.jade.withValues(alpha: 0.4)),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.autorenew_rounded, size: 13, color: AppColors.deepEmerald),
                      SizedBox(width: 5),
                      Text(
                        'Instant Swap @ ₦1,520/USDT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Step 2: Fiat Bank Payout Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E5A3E), Color(0xFF093E2B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepEmerald.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: AppColors.electricMint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'GTBank • 0123•••891',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB5D4C7),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '₦760,000.00',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.electricMint,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.electricMint.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Credited in 38s',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.electricMint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Trust Badges
          Row(
            children: [
              Expanded(child: _buildMicroBadge(Icons.speed_rounded, 'Under 60s Payout')),
              Expanded(child: _buildMicroBadge(Icons.shield_outlined, 'No P2P Delays')),
              Expanded(child: _buildMicroBadge(Icons.verified_outlined, 'Direct Rails')),
            ],
          ),
        ],
      ),
    );
  }

  // Page 2 Illustration: 15-Minute Rate Lock & Slippage Shield
  Widget _buildRateLockIllustration() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.sageBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepEmerald.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Countdown Dial with Lock
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lightMint,
              border: Border.all(color: AppColors.jade, width: 3.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.jade.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, color: AppColors.deepEmerald, size: 20),
                SizedBox(height: 2),
                Text(
                  '14:59',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepEmerald,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'RATE LOCKED',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.forestGreen,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Locked Exchange Rate Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.porcelainSage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sageBorder),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.jade, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Locked Exchange Rate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₦1,520.00 / \$',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepEmerald,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Slippage Protection Comparison Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBF9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sageBorder.withValues(alpha: 0.6)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Market Volatility',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.mutedSage,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '₦1,485.00 (-2.3%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: AppColors.mutedSage, size: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Your Protected Rate',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.mutedSage,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '₦1,520 (0% Slip)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Page 3 Illustration: Double-Entry Ledger & Verified Institutional Security
  Widget _buildSecurityLedgerIllustration() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.sageBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepEmerald.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Identity & Tier Badge
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.lightMint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.jade, width: 1.5),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.deepEmerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified Off-Ramp User',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'BVN / Ghana Card Verified',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.mutedSage,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.deepEmerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.electricMint, size: 11),
                    SizedBox(width: 3),
                    Text(
                      'TIER 2',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Double-Entry Ledger Preview Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.porcelainSage,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sageBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: AppColors.deepEmerald, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Double-Entry Ledger',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'IMMUTABLE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.jade,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.sageBorder, height: 14),
                _buildLedgerLine(
                  label: 'DEBIT (Custody Vault)',
                  amount: '- 500.00 USDT',
                  isCredit: false,
                ),
                const SizedBox(height: 4),
                _buildLedgerLine(
                  label: 'CREDIT (Bank Clearing)',
                  amount: '+ ₦760,000.00',
                  isCredit: true,
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightMint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      '✓ Audited Balance = 0 (Zero Discrepancy)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepEmerald,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Security Features Footer
          Row(
            children: [
              Expanded(child: _buildMicroBadge(Icons.lock_outline_rounded, 'AES-256 Bit')),
              Expanded(child: _buildMicroBadge(Icons.fingerprint_rounded, 'PIN Protected')),
              Expanded(child: _buildMicroBadge(Icons.history_edu_rounded, 'Audit Trail')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerLine({
    required String label,
    required String amount,
    required bool isCredit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedSage,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isCredit ? AppColors.deepEmerald : const Color(0xFFB45309),
          ),
        ),
      ],
    );
  }

  Widget _buildMicroBadge(IconData icon, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.deepEmerald),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedSage,
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingItem {
  final String badge;
  final IconData badgeIcon;
  final String headlineFirst;
  final String headlineAccent;
  final String description;

  const OnboardingItem({
    required this.badge,
    required this.badgeIcon,
    required this.headlineFirst,
    required this.headlineAccent,
    required this.description,
  });
}

class _GoogleGLogoWidget extends StatelessWidget {
  const _GoogleGLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFFEA4335),
                  Color(0xFFFBBC05),
                  Color(0xFF34A853),
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
          ),
        ),
      ),
    );
  }
}
