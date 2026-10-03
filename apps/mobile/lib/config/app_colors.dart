import 'package:flutter/material.dart';

/// "Green & Its Cousins" Design System Palette
/// Curated for a minimal, premium crypto-to-fiat off-ramp experience.
class AppColors {
  // Primary Action & Highlights (Electric Mint / Jade)
  static const Color electricMint = Color(0xFF00E599);
  static const Color jade = Color(0xFF10B981);
  static const Color lightMint = Color(0xFFE6FDF4);

  // High-Emphasis & Cards (Deep Emerald)
  static const Color deepEmerald = Color(0xFF0E5A3E);
  static const Color forestGreen = Color(0xFF0A3F2C);
  static const Color emeraldSurface = Color(0xFF133B2B);

  // Dark Zone, Sheets & Contrast Containers (Obsidian Forest)
  static const Color obsidianForest = Color(0xFF0A140F);
  static const Color darkCard = Color(0xFF111C16);
  static const Color darkCardBorder = Color(0xFF1E2E25);

  // Canvas & Light Surfaces (Porcelain Sage)
  static const Color porcelainSage = Color(0xFFF6FAF7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color sageCard = Color(0xFFEEF4F0);
  static const Color sageBorder = Color(0xFFDCE6E0);

  // Text & Secondary Hierarchy
  static const Color textDark = Color(0xFF0D1C14);
  static const Color textLight = Color(0xFFF1F8F4);
  static const Color mutedSage = Color(0xFF5E7368);
  static const Color mutedSubtext = Color(0xFF8A9E94);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [electricMint, jade],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [deepEmerald, forestGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [darkCard, Color(0xFF0D1912)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sageGlowGradient = LinearGradient(
    colors: [Color(0xFFEAF5EE), porcelainSage],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
