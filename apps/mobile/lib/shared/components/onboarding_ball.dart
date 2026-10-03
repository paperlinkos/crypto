import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OnboardingBall — a self-contained soft rubber ball with realistic physics.
//
//  Public API (via GlobalKey<OnboardingBallState>):
//    startBounce()          – starts the idle physics loop from rest at top
//    resetBounce()          – instantly resets ball to top, restarts physics
//    triggerLaunch()        – strong upward launch (call BEFORE page change)
//    triggerImpact()        – drop-in from top with hard squash (call AFTER
//                             page change, new page's ball starts here)
//
//  Physics summary:
//    • Frame-driven ticker (Ticker, not AnimationController loops) so every
//      frame is a proper Δt physics step — no arbitrary durations.
//    • Gravity pulls the ball down. Impact reverses velocity × restitution.
//    • scaleX / scaleY deform in real-time:
//        – in flight (downward, fast)  → stretch Y / compress X
//        – on impact                   → hard squash X / compress Y
//        – in flight (upward, fast)    → stretch Y / compress X
//        – at apex / settling          → return to 1.0
//    • Restitution decays per bounce, bringing the ball to a tiny idle loop.
//    • ₦ symbol moves & deforms with the ball — no separate transform.
// ─────────────────────────────────────────────────────────────────────────────

enum _BallPhase { idle, bouncing, launching }

class OnboardingBall extends StatefulWidget {
  final Color ballColor;
  final Color ballShine;
  final String symbol;

  const OnboardingBall({
    super.key,
    required this.ballColor,
    required this.ballShine,
    required this.symbol,
  });

  @override
  State<OnboardingBall> createState() => OnboardingBallState();
}

class OnboardingBallState extends State<OnboardingBall>
    with SingleTickerProviderStateMixin {
  // ── Ticker ──────────────────────────────────────────────────────────────
  late final Ticker _ticker;
  Duration _lastTime = Duration.zero;

  // ── Physics state ────────────────────────────────────────────────────────
  // All Y positions are 0..1 within the paint area (0 = top, 1 = bottom).
  // groundY is where the ball "sits" — adjusted to leave shadow room.
  static const double _groundY = 0.88;
  static const double _startY = 0.10;

  double _posY = _startY;
  double _velY = 0.0; // positive = downward

  // gravity in units/s^2 — high enough to feel weighty
  static const double _gravity = 3.6;

  // Restitution: energy retained per bounce. Decays toward _minRestitution.
  double _restitution = 0.78;
  static const double _minRestitution = 0.30;
  static const double _restitutionDecay = 0.06; // per bounce

  // ── Deformation state ────────────────────────────────────────────────────
  double _scaleX = 1.0;
  double _scaleY = 1.0;

  // How hard the squash is; recovered over time
  double _squashTarget = 1.0;
  static const double _squashRecoverySpeed = 12.0;

  // Max stretch/squash magnitudes
  static const double _maxStretch = 0.22; // scaleY max above 1.0
  static const double _maxSquash = 0.35; // scaleY min below 1.0

  // Peak speed expected (units/s) — used to normalise stretch amount
  double _peakSpeed = 0.0;

  // ── Shadow ──────────────────────────────────────────────────────────────
  double _shadowOpacity = 0.0;
  double _shadowScale = 0.0;

  // ── Phase ───────────────────────────────────────────────────────────────
  _BallPhase _phase = _BallPhase.idle;
  bool _settled = false; // ball is in tiny idle oscillation

  // Subtle idle oscillation when ball has nearly settled
  double _idleTime = 0.0;
  static const double _idleAmplitude = 0.012;
  static const double _idleFreq = 1.8; // Hz

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    startBounce();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Start normal idle bounce from the top.
  void startBounce() {
    _posY = _startY;
    _velY = 0.0;
    _scaleX = 1.0;
    _scaleY = 1.0;
    _restitution = 0.78;
    _peakSpeed = 0.0;
    _settled = false;
    _phase = _BallPhase.bouncing;
    _lastTime = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  /// Hard reset — same as startBounce but also kills any mid-launch.
  void resetBounce() {
    _ticker.stop();
    startBounce();
  }

  /// Strong upward launch — call this before triggering the page swipe.
  /// The ball shoots upward and off-screen; listener [onLaunched] fires
  /// once it has cleared the top so you can switch the page.
  void triggerLaunch({VoidCallback? onLaunched}) {
    _phase = _BallPhase.launching;
    _velY = -3.8; // strong upward
    _scaleX = 0.85;
    _scaleY = 1.25;
    _settled = false;
    HapticFeedback.mediumImpact();
    _launchCallback = onLaunched;
    if (!_ticker.isActive) _ticker.start();
  }

  VoidCallback? _launchCallback;

  /// Drop-in from above + hard impact squash — call this on the new page's
  /// ball right after the page transition completes.
  void triggerImpact() {
    _posY = -0.05;
    _velY = 2.8; // fast downward entry
    _scaleX = 0.9;
    _scaleY = 1.2;
    _restitution = 0.72;
    _peakSpeed = 0.0;
    _settled = false;
    _phase = _BallPhase.bouncing;
    _lastTime = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  // ── Ticker callback ──────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;
    if (dt <= 0 || dt > 0.05) return; // skip bad frames

    setState(() {
      if (_settled) {
        _tickIdle(dt);
      } else if (_phase == _BallPhase.launching) {
        _tickLaunch(dt);
      } else {
        _tickBounce(dt);
      }
    });
  }

  // ── Physics ticks ────────────────────────────────────────────────────────

  void _tickBounce(double dt) {
    // Apply gravity
    _velY += _gravity * dt;
    _posY += _velY * dt;

    // Track peak speed for normalised stretch
    if (_velY.abs() > _peakSpeed) _peakSpeed = _velY.abs();

    // Squash/stretch from velocity
    _applyVelocityDeform();

    // Recover squash smoothly
    _scaleX += (_squashTarget - _scaleX) * _squashRecoverySpeed * dt;
    _scaleY += (1.0 / _squashTarget - _scaleY) * _squashRecoverySpeed * dt;

    // Ground collision
    if (_posY >= _groundY) {
      _posY = _groundY;
      final impactSpeed = _velY.abs();

      // Haptic only on significant impacts
      if (impactSpeed > 0.4) {
        HapticFeedback.lightImpact();
      }

      // Apply squash proportional to impact speed
      final normalised = (impactSpeed / (_peakSpeed.clamp(0.01, 4.0))).clamp(0.0, 1.0);
      final squashAmt = 0.18 + normalised * _maxSquash;
      _squashTarget = 1.0 - squashAmt;

      // Rebound
      _velY = -_velY * _restitution;

      // Decay restitution (each bounce a bit smaller)
      _restitution = (_restitution - _restitutionDecay).clamp(_minRestitution, 1.0);

      // Settle check — if the rebound is tiny, switch to idle loop
      if (_velY.abs() < 0.08) {
        _settled = true;
        _posY = _groundY;
        _velY = 0;
        _idleTime = 0;
        _squashTarget = 1.0;
      }
    }

    // Shadow
    final heightRatio = 1.0 - (_posY / _groundY).clamp(0.0, 1.0);
    _shadowOpacity = 0.15 + heightRatio * 0.35;
    _shadowScale = 0.5 + heightRatio * 0.5;
  }

  void _tickLaunch(double dt) {
    _velY += _gravity * dt; // gravity decelerates upward motion
    _posY += _velY * dt;

    // Stretch while going up fast
    if (_velY < 0) {
      final stretch = (-_velY / 4.0).clamp(0.0, _maxStretch);
      _scaleY = 1.0 + stretch;
      _scaleX = 1.0 / _scaleY;
    }

    // Shadow fades as ball leaves
    _shadowOpacity = (_posY / _groundY).clamp(0.0, 0.5) * 0.4;
    _shadowScale = (_posY / _groundY).clamp(0.1, 1.0);

    // Once above screen, fire callback
    if (_posY < -0.2 && _launchCallback != null) {
      final cb = _launchCallback!;
      _launchCallback = null;
      cb();
    }

    // If ball comes back down without callback, switch back to bounce
    if (_velY > 0 && _posY > _startY && _phase == _BallPhase.launching) {
      _phase = _BallPhase.bouncing;
    }
  }

  void _tickIdle(double dt) {
    _idleTime += dt;
    // Tiny sinusoidal bob
    _posY = _groundY - _idleAmplitude * (0.5 + 0.5 * math.sin(2 * math.pi * _idleFreq * _idleTime));
    // Subtle matching deformation
    final bob = 0.5 + 0.5 * math.sin(2 * math.pi * _idleFreq * _idleTime);
    _scaleY = 1.0 + bob * 0.025;
    _scaleX = 1.0 / _scaleY;
    _shadowOpacity = 0.42 + bob * 0.08;
    _shadowScale = 0.92 + bob * 0.08;
  }

  void _applyVelocityDeform() {
    final speed = _velY.abs();
    final ref = _peakSpeed.clamp(0.5, 4.0);
    final t = (speed / ref).clamp(0.0, 1.0);

    // Only apply stretch/squeeze when squash is near neutral
    if (_squashTarget > 0.85) {
      final stretch = t * _maxStretch;
      if (_velY > 0) {
        // Falling — stretch downward
        _scaleY = 1.0 + stretch;
        _scaleX = 1.0 / _scaleY;
      } else if (_velY < -0.1) {
        // Rising — stretch upward
        _scaleY = 1.0 + stretch * 0.7;
        _scaleX = 1.0 / _scaleY;
      } else {
        _scaleY = 1.0;
        _scaleX = 1.0;
      }
    }
  }

  // ── Paint ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: resetBounce,
      child: CustomPaint(
        painter: _BallPainter(
          posY: _posY,
          scaleX: _scaleX,
          scaleY: _scaleY,
          ballColor: widget.ballColor,
          ballShine: widget.ballShine,
          symbol: widget.symbol,
          shadowOpacity: _shadowOpacity,
          shadowScale: _shadowScale,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter
// ─────────────────────────────────────────────────────────────────────────────

class _BallPainter extends CustomPainter {
  final double posY;        // 0..1 normalised position in paint area
  final double scaleX;      // horizontal deformation
  final double scaleY;      // vertical deformation
  final Color ballColor;
  final Color ballShine;
  final String symbol;
  final double shadowOpacity;
  final double shadowScale;

  const _BallPainter({
    required this.posY,
    required this.scaleX,
    required this.scaleY,
    required this.ballColor,
    required this.ballShine,
    required this.symbol,
    required this.shadowOpacity,
    required this.shadowScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseRadius = size.width * 0.30;

    // Centre Y of ball in canvas pixels
    final cy = posY * size.height;

    // Actual drawn radii after deformation
    final rx = baseRadius * scaleX;
    final ry = baseRadius * scaleY;

    // ── Ground shadow ────────────────────────────────────────────────────
    final groundPx = 0.88 * size.height;
    if (shadowOpacity > 0) {
      final shadowPaint = Paint()
        ..color = ballColor.withValues(alpha: shadowOpacity * 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, groundPx + 10),
          width: baseRadius * 2.4 * shadowScale,
          height: 18 * shadowScale,
        ),
        shadowPaint,
      );
    }

    // ── Outer glow ────────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..color = ballColor.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2.5, height: ry * 2.5),
      glowPaint,
    );

    // ── Ball body — radial gradient gives sphere depth ─────────────────
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.40),
        radius: 0.9,
        colors: [
          ballShine,
          ballColor,
          ballColor.withValues(alpha: 0.82),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      bodyPaint,
    );

    // ── Specular highlight (top-left bright spot) ─────────────────────
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - rx * 0.28, cy - ry * 0.28),
        width: rx * 0.65,
        height: ry * 0.45,
      ),
      highlightPaint,
    );

    // Small sharp white dot
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - rx * 0.30, cy - ry * 0.32),
        width: rx * 0.18,
        height: ry * 0.13,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // ── ₦ Symbol — deforms with ball ─────────────────────────────────
    final fontSize = (baseRadius * 0.90) * math.sqrt(scaleX * scaleY);
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.90),
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.28),
              offset: const Offset(1.5, 2.5),
              blurRadius: 5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Scale the text canvas to match ball deformation
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scaleX, scaleY);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BallPainter old) =>
      old.posY != posY ||
      old.scaleX != scaleX ||
      old.scaleY != scaleY ||
      old.ballColor != ballColor ||
      old.shadowOpacity != shadowOpacity;
}
