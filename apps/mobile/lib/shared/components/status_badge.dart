import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String display = status.toUpperCase();

    switch (display) {
      case 'CONFIRMED':
      case 'PROCESSED':
      case 'SUCCESS':
      case 'APPROVED':
        bgColor = AppColors.lightMint;
        textColor = AppColors.deepEmerald;
        break;
      case 'DETECTED':
      case 'PROCESSING':
      case 'PENDING':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        break;
      case 'FAILED':
      case 'REJECTED':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        break;
      default:
        bgColor = AppColors.sageCard;
        textColor = AppColors.mutedSage;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
