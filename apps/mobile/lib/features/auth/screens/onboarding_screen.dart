import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';

// ─────────────────────────────────────────────
//  Data model for each onboarding page
// ─────────────────────────────────────────────
class _OnboardingPage {
  final String badge;
  final String headline;
  final String highlight;
  final String body;
  final Color coinColor;
  final Color coinShine;
  final String symbol;

  const _OnboardingPage({
    required this.badge,
    required this.headline,
    required this.highlight,
    required this.body,
    required this.coinColor,
    required this.coinShine,
    required this.symbol,
  });
}

const _pages = [
  _OnboardingPage(
    badge: '⚡  INSTANT SETTLEMENT',
    headline: 'Crypto to Naira,\nDirect to ',
    highlight: 'Your Bank.',
    body:
        'Receive USDT, USDC or BTC at your personal address. Get paid in NGN or GHS in under 60 seconds at live locked rates.',
    coinColor: Color(0xFF00E599),
    coinShine: Color(0xFFA7FFD8),
    symbol: '₮',
  ),
  _OnboardingPage(
    badge: '🔒  15-MIN RATE LOCK',
    headline: 'Guaranteed Rate,\nZero ',
    highlight: 'Slippage.',
    body:
        'Your rate is locked the moment your deposit is detected on-chain. No nasty surprises — what you see is what hits your account.',
    coinColor: Color(0xFFF59E0B),
    coinShine: Color(0xFFFFE08A),
    symbol: '₿',
  ),
  _OnboardingPage(
    badge: '🛡  INSTITUTIONAL GRADE',
    headline: 'Double-Entry Ledger.\nYour Money, ',
    highlight: 'Fully Safe.',
    body:
        'Every kobo is tracked in a tamper-proof ledger. KYC-tiered limits keep your account safe while you scale.',
    coinColor: Color(0xFF10B981),
    coinShine: Color(0xFF6EFFD4),
    symbol: '₦',
  ),
];

// ─────────────────────────────────────────────
//  Coin physics painter
// ─────────────────────────────────────────────
class _CoinPainter extends CustomPainter {
  final double coinY;
  final double squash;
  final Color coinColor;
  final Color coinShine;
  final String symbol;
  final double rotation;

  const _CoinPainter({
    required this.coinY,
    required this.squash,
    required this.coinColor,
    required this.coinShine,
    required this.symbol,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final radius = size.width * 0.36;
    final cy = coinY * size.height;

    // Shadow
    final shadowPaint = Paint()
      ..color = coinColor.withValues(alpha: 0.25 * (1 - coinY * 0.5))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * squash);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 14),
        width: radius * 2.2 * (1 - (1 - squash) * 0.4),
        height: 20 * squash,
      ),
      shadowPaint,
    );

    // Coin body
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    canvas.scale(1, squash);

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.85,
        colors: [coinShine, coinColor, coinColor.withValues(alpha: 0.85)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, bodyPaint);

    // Inner ring
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset.zero, radius * 0.78, ringPaint);

    // Symbol text
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.92),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(1, 2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoinPainter old) =>
      old.coinY != coinY ||
      old.squash != squash ||
      old.coinColor != coinColor ||
      old.symbol != symbol ||
      old.rotation != rotation;
}

// ─────────────────────────────────────────────
//  Bouncing coin widget
// ─────────────────────────────────────────────
class _BouncingCoin extends StatefulWidget {
  final Color coinColor;
  final Color coinShine;
  final String symbol;

  const _BouncingCoin({
    required this.coinColor,
    required this.coinShine,
    required this.symbol,
  });

  @override
  State<_BouncingCoin> createState() => _BouncingCoinState();
}

class _BouncingCoinState extends State<_BouncingCoin>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  double _y = 0.08;
  double _vy = 0.0;
  double _squash = 1.0;
  double _rotation = 0.0;

  static const double _gravity = 2.8;
  static const double _bounceDamping = 0.62;
  static const double _groundY = 0.82;
  static const double _rotSpeed = 1.2;

  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )
      ..addListener(_tick)
      ..forward();
  }

  void _tick() {
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0 || dt > 0.1) return;

    setState(() {
      _vy += _gravity * dt;
      _y += _vy * dt;
      _rotation += _rotSpeed * dt;

      if (_y >= _groundY) {
        _y = _groundY;
        _vy = -_vy * _bounceDamping;
        _squash = 0.65;
        HapticFeedback.lightImpact();
        if (_vy.abs() < 0.05) {
          _vy = 0;
        }
      }

      if (_squash < 1.0) {
        _squash = (_squash + dt * 8).clamp(0.65, 1.0);
      }
    });
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    setState(() {
      _y = 0.08;
      _vy = 0.0;
      _squash = 1.0;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: CustomPaint(
        painter: _CoinPainter(
          coinY: _y,
          squash: _squash,
          coinColor: widget.coinColor,
          coinShine: widget.coinShine,
          symbol: widget.symbol,
          rotation: _rotation,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Dot indicator
// ─────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;

  const _DotIndicator({
    required this.count,
    required this.current,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : activeColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  Feature chips
// ─────────────────────────────────────────────
class _FeatureChips extends StatelessWidget {
  final List<String> chips;
  final Color color;

  const _FeatureChips({required this.chips, required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            c,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  Tap hint (auto-fades)
// ─────────────────────────────────────────────
class _TapHint extends StatefulWidget {
  final Color color;
  const _TapHint({required this.color});

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _ctrl.forward();
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) _ctrl.reverse();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded,
              color: widget.color.withValues(alpha: 0.55), size: 15),
          const SizedBox(width: 5),
          Text(
            'Tap to bounce again',
            style: TextStyle(
              fontSize: 12,
              color: widget.color.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Main onboarding screen
// ─────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static const _chipSets = [
    ['USDT', 'USDC', 'BTC', 'ETH'],
    ['NGN', 'GHS', 'Live Rates'],
    ['KYC Verified', 'Double-Entry', 'Audit Log'],
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _goToPage(_currentPage + 1);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final size = MediaQuery.of(context).size;
    final safePad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppColors.obsidianForest,
      body: Stack(
        children: [
          // Ambient glow blob
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            top: -80,
            left: _currentPage == 0
                ? -40
                : _currentPage == 1
                    ? size.width / 2 - 140
                    : size.width - 200,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    page.coinColor.withValues(alpha: 0.20),
                    page.coinColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Pages
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (_, index) => _buildPage(index),
          ),

          // Bottom controls overlay
          Positioned(
            left: 24,
            right: 24,
            bottom: safePad.bottom + 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotIndicator(
                  count: _pages.length,
                  current: _currentPage,
                  activeColor: page.coinColor,
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _next,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          page.coinColor,
                          page.coinShine.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: page.coinColor.withValues(alpha: 0.42),
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
                if (_currentPage < _pages.length - 1)
                  GestureDetector(
                    onTap: () => context.go('/login'),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final page = _pages[index];
    final chips = _chipSets[index];
    final isActive = index == _currentPage;
    final safePad = MediaQuery.of(context).padding;

    return Padding(
      padding: EdgeInsets.only(
        top: safePad.top + 24,
        bottom: 180,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1.0 : 0.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: page.coinColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: page.coinColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                page.badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: page.coinColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Headline
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
                height: 1.2,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(text: page.headline),
                TextSpan(
                  text: page.highlight,
                  style: TextStyle(color: page.coinColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Body
          Text(
            page.body,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mutedSubtext,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),

          // Chips
          _FeatureChips(chips: chips, color: page.coinColor),

          // Coin area
          Expanded(
            child: Stack(
              children: [
                _BouncingCoin(
                  coinColor: page.coinColor,
                  coinShine: page.coinShine,
                  symbol: page.symbol,
                ),
                if (isActive)
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: _TapHint(color: page.coinColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
