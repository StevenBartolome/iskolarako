import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Decorative full-bleed hero header used across screens.
/// Uses a rounded-bottom cutout and a subtle cross-hatch pattern overlay.
class CustomHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final Color? startColor;
  final Color? endColor;

  const CustomHeader({
    super.key,
    required this.child,
    this.height = 280,
    this.startColor,
    this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor ?? AppColors.primaryDark,
            endColor ?? AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Subtle radial glow (amber top-right)
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withAlpha(40),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom rounding
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: child,
          ),
        ],
      ),
    );
  }
}
