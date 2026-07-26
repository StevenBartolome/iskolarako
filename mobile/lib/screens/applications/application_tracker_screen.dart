import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/app_components.dart';


class ApplicationTrackerScreen extends StatelessWidget {
  const ApplicationTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildStep(
                    icon: LucideIcons.send,
                    title: 'Application Submitted',
                    date: 'Oct 10, 2026 · 9:41 AM',
                    description:
                        'Your application and all initial requirements have been received by the portal.',
                    state: _StepState.done,
                    isLast: false,
                  ),
                  _buildStep(
                    icon: LucideIcons.fileCheck2,
                    title: 'Documents Verified',
                    date: 'Oct 12, 2026 · 2:05 PM',
                    description:
                        'All uploaded documents passed authenticity checks. Your file is complete.',
                    state: _StepState.done,
                    isLast: false,
                  ),
                  _buildStep(
                    icon: LucideIcons.search,
                    title: 'Under Review',
                    date: 'Since Oct 14, 2026 · Est. 5–10 business days',
                    description:
                        'The scholarship committee is evaluating your application. You\'ll be notified when a decision is made.',
                    state: _StepState.active,
                    note: 'No action needed from you right now.',
                    isLast: false,
                  ),
                  _buildStep(
                    icon: LucideIcons.award,
                    title: 'Final Decision',
                    date: 'Pending · Awaiting committee',
                    description:
                        'You will be notified once the scholarship committee reaches a final decision.',
                    state: _StepState.future,
                    isLast: false,
                  ),
                  _buildStep(
                    icon: LucideIcons.wallet,
                    title: 'Funds Released',
                    date: 'Pending · Via PayMongo · Blockchain-verified',
                    description:
                        'Upon approval, your stipend will be transferred directly to your registered account.',
                    state: _StepState.future,
                    isLast: true,
                  ),
                ],
              ),
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                      'APPLICATION STATUS',
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
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.rule, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.chevronLeft,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Application\ntracker.',
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.rule, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'DOST-SEI Undergraduate Scholarship',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.primaryDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: 'Under Review',
                        type: StatusType.pending,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applied · Oct 10, 2026  ·  Ref: ISK-2026-04821',
                    style: GoogleFonts.dmMono(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String date,
    required String description,
    required _StepState state,
    required bool isLast,
    String? note,
  }) {
    Color circleColor;
    Color circleBorder;
    Color lineColor;
    Color iconColor;
    Color titleColor;

    switch (state) {
      case _StepState.done:
        circleColor = AppColors.successBg;
        circleBorder = AppColors.primary;
        lineColor = AppColors.primary;
        iconColor = AppColors.primary;
        titleColor = AppColors.primary;
        break;
      case _StepState.active:
        circleColor = AppColors.pendingBg;
        circleBorder = AppColors.amber;
        lineColor = AppColors.rule;
        iconColor = AppColors.amber;
        titleColor = AppColors.amberDeep;
        break;
      case _StepState.future:
        circleColor = AppColors.surfaceAlt;
        circleBorder = AppColors.rule;
        lineColor = AppColors.rule;
        iconColor = AppColors.textMuted;
        titleColor = AppColors.textSecondary;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left timeline column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: circleBorder, width: 2),
                  ),
                  child: Icon(
                    state == _StepState.done ? LucideIcons.check : icon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state == _StepState.active
                        ? AppColors.amber.withAlpha(60)
                        : AppColors.rule,
                  ),
                  boxShadow: state == _StepState.active
                      ? [
                          BoxShadow(
                            color: AppColors.amber.withAlpha(25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Opacity(
                  opacity: state == _StepState.future ? 0.55 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            if (state == _StepState.done)
                              StatusChip(
                                  label: 'Done',
                                  type: StatusType.approved),
                            if (state == _StepState.active)
                              StatusChip(
                                label: '● Active',
                                type: StatusType.pending,
                                showDot: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: state == _StepState.done
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        if (note != null) ...[
                          const SizedBox(height: 10),
                          Divider(height: 1, color: AppColors.rule),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(LucideIcons.info,
                                  size: 12, color: AppColors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  note,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.amberDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, future }
