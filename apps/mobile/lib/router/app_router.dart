import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/otp_verification_screen.dart';
import '../features/auth/screens/pin_setup_screen.dart';
import '../features/calculator/screens/rate_calculator_screen.dart';
import '../features/home/screens/home_dashboard_screen.dart';
import '../features/wallets/screens/deposit_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpVerificationScreen(
            recipient: extra?['recipient'] ?? '',
            password: extra?['password'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/pin-setup',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeDashboardScreen(),
      ),
      GoRoute(
        path: '/deposit',
        builder: (context, state) => const DepositScreen(),
      ),
      GoRoute(
        path: '/calculator',
        builder: (context, state) => const RateCalculatorScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const HomeDashboardScreen(),
      ),
    ],
  );
});
