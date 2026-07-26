import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';


class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                _sectionLabel('Today'),
                _NotifCard(
                  icon: LucideIcons.checkCircle2,
                  iconVariant: _IconVariant.green,
                  title: 'Application Approved! 🎉',
                  message:
                      'Congratulations! Your application for CHED Merit Scholarship has been approved by the provider. Funds will be released soon.',
                  time: '10 minutes ago',
                  isUnread: true,
                  accentType: StatusType.approved,
                  actionLabel: 'View Application →',
                ),
                const SizedBox(height: 10),
                _NotifCard(
                  icon: LucideIcons.wallet,
                  iconVariant: _IconVariant.sky,
                  title: 'Funds Released',
                  message:
                      '₱ 20,000.00 has been transferred to your account via PayMongo for Q2 2026. Ref: PM-20261015-84729',
                  time: '2 hours ago',
                  isUnread: true,
                  accentType: StatusType.released,
                  actionLabel: 'View Receipt →',
                  showVerified: true,
                ),
                const SizedBox(height: 16),
                _sectionLabel('Earlier'),
                _NotifCard(
                  icon: LucideIcons.alertTriangle,
                  iconVariant: _IconVariant.amber,
                  title: 'Action Required',
                  message:
                      'Please upload your Certificate of Registration for the City Government Grant. Deadline: Oct 20, 2026.',
                  time: '5 days ago',
                  isUnread: false,
                  accentType: StatusType.pending,
                  actionLabel: 'Upload Now →',
                ),
                const SizedBox(height: 10),
                _NotifCard(
                  icon: LucideIcons.clock,
                  iconVariant: _IconVariant.red,
                  title: 'Application Deadline Soon',
                  message:
                      'The DOST-SEI Scholarship closes in 5 days. Complete your application before Oct 31, 2026.',
                  time: '1 week ago',
                  isUnread: false,
                  accentType: StatusType.rejected,
                ),
                const SizedBox(height: 10),
                _NotifCard(
                  icon: LucideIcons.graduationCap,
                  iconVariant: _IconVariant.green,
                  title: 'New Match Found',
                  message:
                      'A new scholarship matching your profile — SM Foundation Scholars Program — is now open for applications.',
                  time: '1 week ago',
                  isUnread: false,
                  accentType: StatusType.approved,
                  actionLabel: 'View Scholarship →',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.diamond_rounded,
                      size: 14,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NOTIFICATION ALERTS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amberDeep,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Mark all read',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Alerts &\nnotifications.',
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 14),
            // Tab row
            Row(
              children: [
                _TabItem(label: 'All', badge: '4', isActive: true),
                const SizedBox(width: 20),
                _TabItem(label: 'Updates', isActive: false),
                const SizedBox(width: 20),
                _TabItem(label: 'Reminders', isActive: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.rule)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textMuted,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.rule)),
        ],
      ),
    );
  }
}

// ─── Notification card ───────────────────────────────────────────────────────

enum _IconVariant { green, amber, sky, red }

class _NotifCard extends StatelessWidget {
  final IconData icon;
  final _IconVariant iconVariant;
  final String title;
  final String message;
  final String time;
  final bool isUnread;
  final StatusType accentType;
  final String? actionLabel;
  final bool showVerified;

  const _NotifCard({
    required this.icon,
    required this.iconVariant,
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.accentType,
    this.actionLabel,
    this.showVerified = false,
  });

  Color get _accentColor {
    switch (accentType) {
      case StatusType.approved:
        return AppColors.primary;
      case StatusType.pending:
        return AppColors.amber;
      case StatusType.released:
        return AppColors.released;
      case StatusType.rejected:
        return AppColors.error;
      case StatusType.info:
        return AppColors.textSecondary;
    }
  }

  Color get _iconBg {
    switch (iconVariant) {
      case _IconVariant.green:
        return AppColors.successBg;
      case _IconVariant.amber:
        return AppColors.pendingBg;
      case _IconVariant.sky:
        return AppColors.releasedBg;
      case _IconVariant.red:
        return AppColors.errorBg;
    }
  }

  Color get _iconColor {
    switch (iconVariant) {
      case _IconVariant.green:
        return AppColors.primary;
      case _IconVariant.amber:
        return AppColors.amber;
      case _IconVariant.sky:
        return AppColors.released;
      case _IconVariant.red:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.rule, width: 0.5),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: _accentColor.withAlpha(18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          if (actionLabel != null || showVerified) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (actionLabel != null)
                  StatusChip(label: actionLabel!, type: accentType),
                if (showVerified) const VerifiedBadge(),
              ],
            ),
          ],
        ],
      ),
    );

    if (isUnread) {
      card = Stack(
        children: [
          card,
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Container(width: 4, color: _accentColor),
            ),
          ),
        ],
      );
    }

    return card;
  }
}

// ─── Tab item ────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isActive;

  const _TabItem({required this.label, this.badge, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.primaryDark
                    : AppColors.textMuted,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 32 : 0,
          height: 2.5,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
