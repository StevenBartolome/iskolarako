import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/widgets/custom_text_field.dart';

class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({super.key});

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Track uploaded documents
  final Map<String, String?> _uploadedFiles = {
    'grades': null,
    'cor': null,
    'income': null,
    'brgy': null,
    'birth': null,
  };

  void _simulateUpload(String key, String title) {
    if (_uploadedFiles[key] != null) {
      setState(() {
        _uploadedFiles[key] = null;
      });
    } else {
      setState(() {
        _uploadedFiles[key] = '${title.replaceAll(" ", "_").toLowerCase()}_signed.pdf';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title uploaded successfully!'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apply Scholarship',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepContent(),
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${((_currentStep + 1) / _totalSteps * 100).toInt()}%',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              minHeight: 6,
              backgroundColor: AppColors.textSecondary.withAlpha(20),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1(key: const ValueKey(0));
      case 1:
        return _buildStep2(key: const ValueKey(1));
      case 2:
        return _buildStep3(key: const ValueKey(2));
      case 3:
        return _buildStep4(key: const ValueKey(3));
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Let\'s start with your basic details.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        const CustomTextField(label: 'Full Name', hint: 'Juan Dela Cruz', prefixIcon: LucideIcons.user),
        const SizedBox(height: 16),
        const CustomTextField(label: 'Date of Birth', hint: 'MM/DD/YYYY', prefixIcon: LucideIcons.calendar),
        const SizedBox(height: 16),
        const CustomTextField(label: 'Phone Number', hint: '+63 912 345 6789', prefixIcon: LucideIcons.phone),
      ],
    );
  }

  Widget _buildStep2({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Academic Details',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tell us about your educational background.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        const CustomTextField(label: 'University/School', hint: 'Enter institution name', prefixIcon: LucideIcons.school),
        const SizedBox(height: 16),
        const CustomTextField(label: 'Course/Degree', hint: 'BS Computer Science', prefixIcon: LucideIcons.bookOpen),
        const SizedBox(height: 16),
        const CustomTextField(label: 'Current Year Level', hint: 'e.g. 3rd Year', prefixIcon: LucideIcons.barChart2),
      ],
    );
  }

  Widget _buildStep3({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submit Requirements',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Please upload the required files by category section.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Section A: Academic Requirements
        _buildSectionTitle('SECTION A: ACADEMIC DOCUMENTS'),
        const SizedBox(height: 10),
        _buildUploadCard(
          title: 'Transcript of Records / Report Card',
          description: 'Upload latest grades (PDF, Max 5MB)',
          docKey: 'grades',
        ),
        const SizedBox(height: 12),
        _buildUploadCard(
          title: 'Certificate of Registration (COR)',
          description: 'Official enrollment form for current term',
          docKey: 'cor',
        ),

        const SizedBox(height: 24),

        // Section B: Financial Requirements
        _buildSectionTitle('SECTION B: FINANCIAL DOCUMENTS'),
        const SizedBox(height: 10),
        _buildUploadCard(
          title: 'Income Tax Return (ITR) / Indigency Cert',
          description: 'Proof of family annual income',
          docKey: 'income',
        ),

        const SizedBox(height: 24),

        // Section C: Personal Identification
        _buildSectionTitle('SECTION C: PERSONAL IDENTIFICATION'),
        const SizedBox(height: 10),
        _buildUploadCard(
          title: 'Barangay Clearance',
          description: 'Issued within the last 6 months',
          docKey: 'brgy',
        ),
        const SizedBox(height: 12),
        _buildUploadCard(
          title: 'PSA Birth Certificate',
          description: 'Clear copy of birth registry document',
          docKey: 'birth',
        ),
      ],
    );
  }

  Widget _buildStep4({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Final Review',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Almost there! Please verify your information.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 64),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'By submitting, you confirm that all information and uploaded documents provided are accurate and true to the best of your knowledge.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String description,
    required String docKey,
  }) {
    final fileName = _uploadedFiles[docKey];
    final isUploaded = fileName != null;

    return GestureDetector(
      onTap: () => _simulateUpload(docKey, title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUploaded ? AppColors.successBg : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUploaded ? AppColors.success : AppColors.rule,
            width: isUploaded ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUploaded ? AppColors.success.withAlpha(20) : AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUploaded ? LucideIcons.fileCheck2 : LucideIcons.uploadCloud,
                color: isUploaded ? AppColors.success : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isUploaded ? fileName : description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isUploaded ? AppColors.success : AppColors.textSecondary,
                      fontWeight: isUploaded ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isUploaded)
              const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 20)
            else
              Text(
                'Upload',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: CustomButton(
                text: 'Back',
                isOutlined: true,
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: CustomButton(
              text: _currentStep == _totalSteps - 1 ? 'Submit Application' : 'Next Step',
              onPressed: () {
                if (_currentStep < _totalSteps - 1) {
                  setState(() {
                    _currentStep++;
                  });
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application Submitted Successfully!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
