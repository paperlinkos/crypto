import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/components/custom_button.dart';
import '../../../shared/components/custom_text_field.dart';
import '../../../shared/components/pill_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUpMode = false;
  String _authMethod = 'Email'; // 'Email' or 'Phone'

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final identifier = _emailPhoneController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email or phone number')),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    if (_isSignUpMode) {
      // Step 1 of signup: Request OTP
      final success = await ref.read(authProvider.notifier).requestOtp(identifier, purpose: 'SIGNUP');
      if (success && mounted) {
        context.push('/otp-verify', extra: {'recipient': identifier, 'password': password});
      }
    } else {
      // Login directly
      final success = await ref.read(authProvider.notifier).login(
        identifier: identifier,
        password: password,
      );
      if (success && mounted) {
        final authState = ref.read(authProvider);
        if (authState.user?.isPinSet == false) {
          context.go('/pin-setup');
        } else {
          context.go('/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUpMode ? 'Create Account' : 'Welcome Back',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUpMode
                  ? 'Sign up to start converting crypto to local fiat.'
                  : 'Enter your credentials to access your account.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedSage,
                ),
              ),
              const SizedBox(height: 24),

              // Segmented Toggle for Mode
              PillSelector<bool>(
                options: const [false, true],
                selected: _isSignUpMode,
                labelBuilder: (isSignup) => isSignup ? 'Sign Up' : 'Log In',
                onSelected: (val) => setState(() => _isSignUpMode = val),
              ),
              const SizedBox(height: 24),

              // Method Selector (Email / Phone)
              Row(
                children: [
                  _buildMethodChip('Email', Icons.mail_outline),
                  const SizedBox(width: 10),
                  _buildMethodChip('Phone', Icons.phone_outlined),
                ],
              ),
              const SizedBox(height: 20),

              // Input: Email or Phone
              CustomTextField(
                label: _authMethod == 'Email' ? 'Email Address' : 'Phone Number',
                hintText: _authMethod == 'Email' ? 'you@example.com' : '+2348012345678',
                controller: _emailPhoneController,
                keyboardType: _authMethod == 'Email' ? TextInputType.emailAddress : TextInputType.phone,
                prefixIcon: Icon(
                  _authMethod == 'Email' ? Icons.email_outlined : Icons.phone_android_outlined,
                  color: AppColors.mutedSage,
                  size: 20,
                ),
              ),
              const SizedBox(height: 16),

              // Input: Password
              CustomTextField(
                label: 'Password',
                hintText: '••••••••',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.mutedSage, size: 20),
              ),
              const SizedBox(height: 24),

              if (authState.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.error!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              CustomButton(
                text: _isSignUpMode ? 'Continue with OTP' : 'Log In',
                isLoading: authState.isLoading,
                onPressed: _handleSubmit,
              ),

              const SizedBox(height: 20),

              // OR Divider
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: AppColors.sageBorder)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedSage,
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: AppColors.sageBorder)),
                ],
              ),

              const SizedBox(height: 20),

              // Google Sign-In / Sign-Up Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    // Navigate directly into app home
                    context.go('/home');
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.sageBorder, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _GoogleGLogoWidget(),
                      const SizedBox(width: 10),
                      Text(
                        _isSignUpMode ? 'Sign up with Google' : 'Sign in with Google',
                        style: const TextStyle(
                          fontSize: 15,
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
      ),
    );
  }

  Widget _buildMethodChip(String method, IconData icon) {
    final isSelected = _authMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _authMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightMint : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.jade : AppColors.sageBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.deepEmerald : AppColors.mutedSage,
            ),
            const SizedBox(width: 6),
            Text(
              method,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.deepEmerald : AppColors.mutedSage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGLogoWidget extends StatelessWidget {
  const _GoogleGLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFFEA4335),
                  Color(0xFFFBBC05),
                  Color(0xFF34A853),
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 22, 22)),
          ),
        ),
      ),
    );
  }
}
