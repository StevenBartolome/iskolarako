import 'package:flutter/material.dart';

class AppColors {
  // ─── Primary Brand ─────────────────────────────────────────
  /// Deep forest green — primary, verified/approved state
  static const Color primary = Color(0xFF2D5941);
  static const Color primaryDark = Color(0xFF1A3C2E);   // stamp-forest, header bg
  static const Color primaryLight = Color(0xFF3D7A58);  // mid forest for gradients

  // ─── Accent ───────────────────────────────────────────────
  /// Warm amber — pending / action-required state
  static const Color amber = Color(0xFFC97B2E);
  static const Color amberDeep = Color(0xFF7A4A15);
  static const Color gold = Color(0xFFE8A838);          // blockchain, celebration

  // ─── Status ───────────────────────────────────────────────
  static const Color success = Color(0xFF2D5941);       // same as primary
  static const Color pending = Color(0xFFC97B2E);       // amber
  static const Color error = Color(0xFFB34040);         // seal red — rejected, deadline
  static const Color released = Color(0xFF2A6BA8);      // sky blue — funds released

  // ─── Signature Gradient ───────────────────────────────────
  static const LinearGradient signatureGradient = LinearGradient(
    colors: [primaryDark, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [amber, gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Light Theme Surfaces ─────────────────────────────────
  static const Color background = Color(0xFFF9F5EF);   // warm cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEDE8DE);   // parchment — dividers, inputs

  // ─── Text ─────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1C1C1E);  // near-black ink
  static const Color textSecondary = Color(0xFF6C6C70);
  static const Color textMuted = Color(0xFF8E8E93);

  // ─── Rule / Divider ───────────────────────────────────────
  static const Color rule = Color(0xFFD9D2C5);

  // ─── Status Backgrounds ───────────────────────────────────
  static const Color successBg = Color(0xFFEBF5EE);
  static const Color pendingBg = Color(0xFFFDF3E3);
  static const Color errorBg = Color(0xFFFDF0F0);
  static const Color releasedBg = Color(0xFFEAF3FB);

  // ─── Dark Theme ───────────────────────────────────────────
  static const Color darkBackground = Color(0xFF111A15);  // very dark forest
  static const Color darkSurface = Color(0xFF1C2B22);
  static const Color darkTextPrimary = Color(0xFFF4F0E8);
  static const Color darkTextSecondary = Color(0xFF9BA89F);

  // ─── Semantic helpers ────────────────────────────────────
  static Color chipBg(Color base) => base.withAlpha(26);
}
