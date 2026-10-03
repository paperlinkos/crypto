import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainSage,
      body: Stack(
        children: [
          // Main Body Content
          Positioned.fill(
            bottom: 84, // Leave room for floating dock navigation
            child: child,
          ),

          // Floating Pill Dock Navigation
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.obsidianForest,
                borderRadius: BorderRadius.circular(33),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.obsidianForest.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: AppColors.darkCardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                    onTap: () => context.go('/home'),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.qr_code_scanner_outlined,
                    activeIcon: Icons.qr_code_scanner,
                    label: 'Deposit',
                    isSelected: currentIndex == 1,
                    onTap: () => context.go('/deposit'),
                  ),
                  // Centered Quick Action Button
                  GestureDetector(
                    onTap: () => context.go('/calculator'),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: AppColors.obsidianForest,
                        size: 26,
                      ),
                    ),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.calculate_outlined,
                    activeIcon: Icons.calculate,
                    label: 'Rates',
                    isSelected: currentIndex == 2,
                    onTap: () => context.go('/calculator'),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                    isSelected: currentIndex == 3,
                    onTap: () => context.go('/profile'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppColors.electricMint : AppColors.mutedSubtext,
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.electricMint : AppColors.mutedSubtext,
            ),
          ),
        ],
      ),
    );
  }
}
