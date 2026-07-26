import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/widgets/app_components.dart';


class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final int _step = 1;
  static const int _totalSteps = 3;

  static const List<_DocItem> _docs = [
    _DocItem(
      name: 'PSA Birth Certificate',
      hint: 'PDF or JPG · max 5 MB',
      status: _DocStatus.uploaded,
      filename: 'birth_cert_jdc.pdf',
      filesize: '1.2 MB',
    ),
    _DocItem(
      name: 'Form 138 / Report Card',
      hint: 'PDF or JPG · max 5 MB',
      status: _DocStatus.uploaded,
      filename: 'form138_jdc.pdf',
      filesize: '0.8 MB',
    ),
    _DocItem(
      name: 'ITR or Cert. of Indigency',
      hint: 'Required · Not yet uploaded',
      status: _DocStatus.pending,
    ),
    _DocItem(
      name: 'Valid Government ID',
      hint: 'Required · Not yet uploaded',
      status: _DocStatus.notUploaded,
    ),
    _DocItem(
      name: 'Community Service Certificate',
      hint: 'Optional',
      status: _DocStatus.optional,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildUploadZone(),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Required Documents'),
                  const SizedBox(height: 12),
                  ..._docs.map((d) => _DocTile(doc: d)),
                  const SizedBox(height: 22),
                  const SectionHeading(title: 'Personal Information'),
                  const SizedBox(height: 12),
                  _buildField('Full Name', 'Juan dela Cruz'),
                  const SizedBox(height: 10),
                  _buildField('Course & Year', 'BS Computer Science · 1st Year'),
                  const SizedBox(height: 10),
                  _buildField('School / University', 'University of the Philippines'),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.rule)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Save Draft',
                      isOutlined: true,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: 'Submit Application',
                      icon: LucideIcons.send,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '2 of 4 documents uploaded · Complete all required files to submit',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
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
                      'DOCUMENT REPOSITORY',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Upload\ndocuments.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    height: 1.15,
                  ),
                ),
                // Step Dots
                Row(
                  children: List.generate(_totalSteps, (i) {
                    final active = i == _step - 1;
                    final done = i < _step - 1;
                    return Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.primary
                            : active
                                ? AppColors.amber
                                : AppColors.rule,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Step $_step of $_totalSteps — Upload requirements for verification',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withAlpha(80),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.uploadCloud,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to upload or drag & drop',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'JPG, PNG, PDF · Max 10 MB per file',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.rule),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Doc tile ────────────────────────────────────────────────────────────────

enum _DocStatus { uploaded, pending, notUploaded, optional }

class _DocItem {
  final String name;
  final String hint;
  final _DocStatus status;
  final String? filename;
  final String? filesize;

  const _DocItem({
    required this.name,
    required this.hint,
    required this.status,
    this.filename,
    this.filesize,
  });
}

class _DocTile extends StatelessWidget {
  final _DocItem doc;

  const _DocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color iconBg;
    Color iconColor;
    Widget trailing;
    Widget leadingIcon;

    switch (doc.status) {
      case _DocStatus.uploaded:
        borderColor = AppColors.primary.withAlpha(60);
        iconBg = AppColors.successBg;
        iconColor = AppColors.primary;
        leadingIcon = const Icon(LucideIcons.check, size: 18);
        trailing = StatusChip(label: 'Uploaded', type: StatusType.approved);
        break;
      case _DocStatus.pending:
        borderColor = AppColors.amber.withAlpha(80);
        iconBg = AppColors.pendingBg;
        iconColor = AppColors.amber;
        leadingIcon = const Icon(LucideIcons.uploadCloud, size: 18);
        trailing = StatusChip(label: 'Pending', type: StatusType.pending);
        break;
      case _DocStatus.notUploaded:
        borderColor = AppColors.rule;
        iconBg = AppColors.surfaceAlt;
        iconColor = AppColors.textMuted;
        leadingIcon = const Icon(LucideIcons.fileText, size: 18);
        trailing = StatusChip(label: 'Upload', type: StatusType.info);
        break;
      case _DocStatus.optional:
        borderColor = AppColors.rule;
        iconBg = AppColors.surfaceAlt;
        iconColor = AppColors.textMuted;
        leadingIcon = const Icon(LucideIcons.fileText, size: 18);
        trailing = StatusChip(label: 'Optional', type: StatusType.info);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: doc.status == _DocStatus.pending
            ? AppColors.pendingBg
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ColoredBox(
              color: Colors.transparent,
              child: IconTheme(
                data: IconThemeData(color: iconColor),
                child: Center(child: leadingIcon),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doc.filename != null
                      ? '${doc.filename} · ${doc.filesize}'
                      : doc.hint,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
