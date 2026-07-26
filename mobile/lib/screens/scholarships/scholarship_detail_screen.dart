import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/widgets/app_components.dart';
import 'package:iskoako/widgets/custom_header.dart';


class ScholarshipDetailScreen extends StatelessWidget {
  const ScholarshipDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBar(),
                  const SizedBox(height: 16),
                  _buildDeadlineAlert(),
                  const SizedBox(height: 22),
                  _buildSection(
                    title: 'About this Scholarship',
                    content:
                        'The DOST-SEI Undergraduate Scholarships are awarded to deserving students who wish to pursue degree programs in basic sciences, mathematics, and engineering in accredited HEIs across the Philippines.',
                  ),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Coverage & Benefits'),
                  const SizedBox(height: 12),
                  _buildBulletList([
                    '₱40,000 monthly stipend',
                    'Full tuition and miscellaneous fees',
                    'Book allowance ₱10,000 per year',
                    'Thesis / dissertation grant',
                  ]),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Eligibility Requirements'),
                  const SizedBox(height: 12),
                  _buildCheckList([
                    'Natural-born Filipino citizen',
                    'Top 5% of graduating class (STEM strand)',
                    'Annual family income ≤ ₱1,500,000',
                    'No other active government scholarship',
                  ]),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Documents to Prepare'),
                  const SizedBox(height: 12),
                  _buildDocList([
                    'PSA Birth Certificate',
                    'Form 138 / Report Card',
                    'ITR or Certificate of Indigency',
                    'Valid Government ID',
                  ]),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: CustomButton(
            text: 'Apply for this Scholarship',
            icon: LucideIcons.send,
            onPressed: () =>
                Navigator.pushNamed(context, AppRouter.documentUpload),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return CustomHeader(
      height: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.chevronLeft,
                        color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.share2,
                      color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip(
                      label: 'Government · DOST',
                      type: StatusType.approved,
                    ),
                    StatusChip(
                      label: 'Merit-based',
                      type: StatusType.info,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'DOST-SEI Undergraduate Scholarship',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Department of Science & Technology',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(160),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            _InfoBarItem(value: '₱40k', label: 'Per Semester', isMono: true),
            VerticalDivider(width: 1, color: AppColors.rule),
            _InfoBarItem(value: '4 yrs', label: 'Duration'),
            VerticalDivider(width: 1, color: AppColors.rule),
            _InfoBarItem(value: '100', label: 'Slots'),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineAlert() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application closes in 5 days',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
              Text(
                'October 31, 2026 · 11:59 PM',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.error.withAlpha(180)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: title),
        const SizedBox(height: 10),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.65,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletList(List<String> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCheckList(List<String> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.check,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocList(List<String> items) {
    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.rule),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.pendingBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(LucideIcons.fileText,
                    size: 18, color: AppColors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(LucideIcons.upload,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Info bar item ──────────────────────────────────────────────────────────

class _InfoBarItem extends StatelessWidget {
  final String value;
  final String label;
  final bool isMono;

  const _InfoBarItem({
    required this.value,
    required this.label,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              value,
              style: isMono
                  ? GoogleFonts.dmMono(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    )
                  : GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
