import 'package:flutter/material.dart';
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
  final int _totalSteps = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Scholarship'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${_currentStep + 1} of $_totalSteps',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('${((_currentStep + 1) / _totalSteps * 100).toInt()}%',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              minHeight: 8,
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
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personal Information', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Let\'s start with your basic details.', style: Theme.of(context).textTheme.bodyMedium),
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
        Text('Academic Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Tell us about your educational background.', style: Theme.of(context).textTheme.bodyMedium),
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
        Text('Final Review', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Almost there! Please verify your information.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 32),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 64),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'By submitting, you confirm that all information provided is accurate and true to the best of your knowledge.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
      ],
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
