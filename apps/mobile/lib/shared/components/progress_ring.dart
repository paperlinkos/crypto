import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String centerText;
  final String? subText;
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.centerText,
    this.subText,
    this.size = 110,
    this.strokeWidth = 8,
    this.progressColor = AppColors.electricMint,
    this.backgroundColor = AppColors.sageBorder,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(backgroundColor),
            ),
          ),
          // Active Progress
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clampedProgress,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          // Center Information
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                centerText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: -0.2,
                ),
              ),
              if (subText != null) ...[
                const SizedBox(height: 2),
                Text(
                  subText!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedSage,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
