import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

// ─── Status Chip ────────────────────────────────────────────────────────────

enum StatusType { approved, pending, rejected, released, info }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;
  final bool showDot;

  const StatusChip({
    super.key,
    required this.label,
    this.type = StatusType.info,
    this.showDot = false,
  });

  Color get _bg {
    switch (type) {
      case StatusType.approved:
        return AppColors.successBg;
      case StatusType.pending:
        return AppColors.pendingBg;
      case StatusType.rejected:
        return AppColors.errorBg;
      case StatusType.released:
        return AppColors.releasedBg;
      case StatusType.info:
        return AppColors.surfaceAlt;
    }
  }

  Color get _fg {
    switch (type) {
      case StatusType.approved:
        return AppColors.primary;
      case StatusType.pending:
        return AppColors.amberDeep;
      case StatusType.rejected:
        return AppColors.error;
      case StatusType.released:
        return AppColors.released;
      case StatusType.info:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fg.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _fg),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Heading ────────────────────────────────────────────────────────

class SectionHeading extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Verified Badge (blockchain) ─────────────────────────────────────────────

class VerifiedBadge extends StatelessWidget {
  final String label;

  const VerifiedBadge({super.key, this.label = 'Chain-verified'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── App Card wrapper ─────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderLeftColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderLeftColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    Widget card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.rule, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );

    if (borderLeftColor != null) {
      card = Stack(
        children: [
          card,
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              child: Container(
                width: 4,
                color: borderLeftColor,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(onTap: onTap, child: card);
  }
}
