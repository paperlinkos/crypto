import 'package:flutter/material.dart';

/// Design System Color Palette: "Green Gradients and Its Cousins"
/// Tailored for minimal, institutional-grade crypto off-ramp aesthetics.
class AppColors {
  // 1. Primary Greens & Accents
  static const Color electricMint = Color(0xFF00E599);
  static const Color jadeGreen = Color(0xFF10B981);
  static const Color richEmerald = Color(0xFF0E5A3E);
  static const Color deepForest = Color(0xFF0A3F2C);

  // 2. Dark Surfaces ("Obsidian Forest" container & dark mode)
  static const Color obsidianForest = Color(0xFF0A140F);
  static const Color darkCardSurface = Color(0xFF121C16);
  static const Color darkCardBorder = Color(0xFF1C2C23);

  // 3. Light Canvas ("Porcelain Sage")
  static const Color canvasPorcelain = Color(0xFFF6FAF7);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2ECE6);

  // 4. Secondary & Text Accents
  static const Color textDark = Color(0xFF0F1A14);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMutedSage = Color(0xFF70877C);
  static const Color textSubtle = Color(0xFF9FB2A8);

  // 5. Status Indicators
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusFailed = Color(0xFFEF4444);
  static const Color statusProcessing = Color(0xFF3B82F6);

  // 6. Signatures Gradients
  static const LinearGradient mintEmeraldGradient = LinearGradient(
    colors: [electricMint, jadeGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkForestGradient = LinearGradient(
    colors: [obsidianForest, Color(0xFF0F2119)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient rateCardGradient = LinearGradient(
    colors: [Color(0xFFE6F7F0), Color(0xFFDCF2E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
