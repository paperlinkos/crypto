import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../shared/components/onboarding_ball.dart';

// ─────────────────────────────────────────────
//  Page model
// ─────────────────────────────────────────────

class _PageModel {
  final String badge;
  final String headline;
  final String accent; // coloured trailing word
  final String body;
  final List<String> chips;
  final Color ballColor;
  final Color ballShine;
  final String symbol;

  const _PageModel({
    required this.badge,
    required this.headline,
    required this.accent,
    required this.body,
    required this.chips,
    required this.ballColor,
    required this.ballShine,
    required this.symbol,
  });
}

const _pages = [
  _PageModel(
    badge: '⚡  INSTANT SETTLEMENT',
    headline: 'Crypto to Naira,\nDirect to ',
    accent: 'Your Bank.',
    body: 'Receive USDT, USDC or BTC at your personal address. Get paid in NGN or GHS in under 60 seconds at live locked rates.',
    chips: ['USDT', 'USDC', 'BTC', 'ETH'],
    ballColor: Color(0xFF00E599),
    ballShine: Color(0xFFB0FFE2),
    symbol: '₮',
  ),
  _PageModel(
    badge: '🔒  15-MIN RATE LOCK',
    headline: 'Guaranteed Rate,\nZero ',
    accent: 'Slippage.',
    body: 'Your rate is locked the moment your deposit is detected on-chain. No nasty surprises — what you see is what hits your account.',
    chips: ['NGN', 'GHS', 'Live Rates'],
    ballColor: Color(0xFFF59E0B),
    ballShine: Color(0xFFFFE08A),
    symbol: '₿',
  ),
  _PageModel(
    badge: '🛡  INSTITUTIONAL GRADE',
    headline: 'Double-Entry Ledger.\nYour Money, ',
    accent: 'Fully Safe.',
    body: 'Every kobo is tracked in a tamper-proof ledger. KYC-tiered limits keep your account safe while you scale.',
    chips: ['KYC Verified', 'Double-Entry', 'Audit Log'],
    ballColor: Color(0xFF10B981),
    ballShine: Color(0xFF6EFFD4),
    symbol: '₦',
  ),
];

// ─────────────────────────────────────────────
//  Onboarding screen
// ─────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  bool _transitioning = false;

  // One GlobalKey per page so we can call the ball's methods
  final List<GlobalKey<OnboardingBallState>> _ballKeys = List.generate(
    _pages.length,
    (_) => GlobalKey<OnboardingBallState>(),
  );

  // Content fade/slide animation
  late final AnimationController _contentCtrl;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));
    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _advance() {
    if (_transitioning) return;
    if (_currentPage >= _pages.length - 1) {
      context.go('/login');
      return;
    }
    _triggerPageTransition(_currentPage + 1);
  }

  void _skip() => context.go('/login');

  void _triggerPageTransition(int nextPage) {
    if (_transitioning) return;
    setState(() => _transitioning = true);

    HapticFeedback.mediumImpact();

    // Step 1 — launch the current ball upward
    _ballKeys[_currentPage].currentState?.triggerLaunch(
      onLaunched: () {
        // Step 2 — switch page (ball has cleared the top)
        if (!mounted) return;
        setState(() {
          _currentPage = nextPage;
          _transitioning = false;
        });

        // Step 3 — animate content text in
        _contentCtrl
          ..reset()
          ..forward();

        // Step 4 — after one frame let the new ball drop in hard
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _ballKeys[nextPage].currentState?.triggerImpact();
        });
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final safePad = MediaQuery.of(context).padding;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.obsidianForest,
      body: Stack(
        children: [
          // ── Ambient glow blob (tracks page) ──────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            top: -80,
            left: _currentPage == 0
                ? -30
                : _currentPage == 1
                    ? size.width / 2 - 150
                    : size.width - 180,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    page.ballColor.withValues(alpha: 0.18),
                    page.ballColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── All ball layers (stacked, only current is visible via
          //    Offstage so keys persist) ──────────────────────────────
          ...List.generate(_pages.length, (i) {
            final p = _pages[i];
            return Positioned.fill(
              child: Offstage(
                offstage: i != _currentPage,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: safePad.top + 24 + _textAreaHeight(context),
                    bottom: _bottomControlsHeight(context) + 16,
                    left: 32,
                    right: 32,
                  ),
                  child: OnboardingBall(
                    key: _ballKeys[i],
                    ballColor: p.ballColor,
                    ballShine: p.ballShine,
                    symbol: p.symbol,
                  ),
                ),
              ),
            );
          }),

          // ── Text content (fades/slides on transition) ─────────────
          Positioned(
            top: safePad.top + 24,
            left: 24,
            right: 24,
            height: _textAreaHeight(context),
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: _buildTextContent(page),
              ),
            ),
          ),

          // ── Bottom controls ───────────────────────────────────────
          Positioned(
            left: 24,
            right: 24,
            bottom: safePad.bottom + 28,
            child: _buildBottomControls(page),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _textAreaHeight(BuildContext ctx) {
    // Text + chips area — leaves plenty of room for the ball
    return MediaQuery.of(ctx).size.height * 0.40;
  }

  double _bottomControlsHeight(BuildContext ctx) {
    return MediaQuery.of(ctx).padding.bottom + 28 + 56 + 22 + 30;
  }

  Widget _buildTextContent(_PageModel page) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: page.ballColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: page.ballColor.withValues(alpha: 0.35)),
          ),
          child: Text(
            page.badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: page.ballColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Headline
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textLight,
              height: 1.22,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: page.headline),
              TextSpan(
                text: page.accent,
                style: TextStyle(color: page.ballColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Body
        Text(
          page.body,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.mutedSubtext,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),

        // Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: page.chips.map((c) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: page.ballColor.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: page.ballColor.withValues(alpha: 0.28)),
              ),
              child: Text(
                c,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: page.ballColor,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomControls(_PageModel page) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pages.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? page.ballColor
                    : page.ballColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 22),

        // CTA button
        GestureDetector(
          onTap: _advance,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  page.ballColor,
                  page.ballShine.withValues(alpha: 0.88),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: page.ballColor.withValues(alpha: 0.40),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _currentPage == _pages.length - 1
                    ? 'Get Started  →'
                    : 'Continue  →',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.obsidianForest,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Skip
        if (_currentPage < _pages.length - 1)
          GestureDetector(
            onTap: _skip,
            child: Text(
              'Skip for now',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedSubtext.withValues(alpha: 0.65),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
