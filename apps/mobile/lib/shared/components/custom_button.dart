import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

enum ButtonVariant { primary, secondary, outline, dark }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.width,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    Decoration decoration;
    Color textColor;

    switch (variant) {
      case ButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: AppColors.electricMint.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
        textColor = AppColors.obsidianForest;
        break;
      case ButtonVariant.secondary:
        decoration = BoxDecoration(
          color: AppColors.deepEmerald,
          borderRadius: BorderRadius.circular(27),
        );
        textColor = Colors.white;
        break;
      case ButtonVariant.dark:
        decoration = BoxDecoration(
          color: AppColors.obsidianForest,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: AppColors.darkCardBorder),
        );
        textColor = AppColors.electricMint;
        break;
      case ButtonVariant.outline:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: AppColors.deepEmerald, width: 1.5),
        );
        textColor = AppColors.deepEmerald;
        break;
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(27),
          child: Ink(
            decoration: decoration,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: textColor, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              text,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
