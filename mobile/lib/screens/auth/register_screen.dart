import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:iskoako/services/audit_log_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  int _currentStep = 1;

  // Step 1 Controllers (Account Info)
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Step 2 Controllers (Personal Info)
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _selectedBirthDate;
  String? _selectedGender;

  // Step 3 Controllers (Academic Details)
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  int? _selectedYearLevel;
  String? _selectedEduLevel = 'college';
  // For incoming_college students
  final TextEditingController _plannedUniversityController = TextEditingController();
  final List<TextEditingController> _plannedCoursesControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _agreedToTerms = false;

  late final AnimationController _heroController;
  late final AnimationController _formController;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _logoFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));

    _formFade = CurvedAnimation(parent: _formController, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      _heroController.forward();
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      _formController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _courseController.dispose();
    _plannedUniversityController.dispose();
    for (final c in _plannedCoursesControllers) { c.dispose(); }
    _heroController.dispose();
    _formController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  bool _validateStep(int step) {
    if (step == 1) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final confirm = _confirmPasswordController.text;
      if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
        _showSnackBar('Please fill in all account fields.', isError: true);
        return false;
      }
      if (!email.contains('@')) {
        _showSnackBar('Please enter a valid email address.', isError: true);
        return false;
      }
      if (password != confirm) {
        _showSnackBar('Passwords do not match.', isError: true);
        return false;
      }
      if (password.length < 6) {
        _showSnackBar('Password must be at least 6 characters.', isError: true);
        return false;
      }
    } else if (step == 2) {
      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final phone = _phoneController.text.trim();
      if (first.isEmpty || last.isEmpty || phone.isEmpty) {
        _showSnackBar('Please fill in all required personal fields.', isError: true);
        return false;
      }
      if (_selectedBirthDate == null) {
        _showSnackBar('Please select your birth date.', isError: true);
        return false;
      }
      if (_selectedGender == null) {
        _showSnackBar('Please select your gender.', isError: true);
        return false;
      }
    }
    return true;
  }

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    setState(() {
      _currentStep--;
    });
  }

  Future<bool> _sendEmailJSVerification({
    required String toName,
    required String toEmail,
    required String code,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': dotenv.env['EMAILJS_SERVICE_ID'] ?? '',
          'template_id': dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '',
          'user_id': dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '',
          'template_params': {
            'to_name': toName,
            'to_email': toEmail,
            'verification_code': code,
          }
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('EmailJS error status ${response.statusCode}: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('EmailJS error: $e');
      return false;
    }
  }

  Future<void> _handleRegister() async {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final middle = _middleNameController.text.trim();
    final suffix = _suffixController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();
    final school = _schoolController.text.trim();
    final course = _courseController.text.trim();

    final bool isIncoming = _selectedEduLevel == 'incoming_college';
    final bool needsSchoolCourse = !isIncoming;

    if (_selectedEduLevel == null) {
      _showSnackBar('Please select your education level.', isError: true);
      return;
    }

    if (needsSchoolCourse && (school.isEmpty || course.isEmpty)) {
      _showSnackBar('Please fill in school and course/strand fields.', isError: true);
      return;
    }

    if (isIncoming && _plannedUniversityController.text.trim().isEmpty) {
      _showSnackBar('Please enter your planned university/college.', isError: true);
      return;
    }

    if (!isIncoming && _selectedYearLevel == null) {
      _showSnackBar('Please select your year/grade level.', isError: true);
      return;
    }

    if (!_agreedToTerms) {
      _showSnackBar('Please agree to the Terms and Conditions.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Generate random 6 digit verification code
    final random = Random();
    String code = (100000 + random.nextInt(900000)).toString();

    // Send via EmailJS
    final bool emailSent = await _sendEmailJSVerification(
      toName: first,
      toEmail: email,
      code: code,
    );

    setState(() => _isLoading = false);

    if (!emailSent) {
      _showSnackBar('Failed to send verification email. Please check connection.', isError: true);
      return;
    }

    if (!mounted) return;

    // Show Verification Bottom Sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _OtpVerificationSheet(
          email: email,
          verificationCode: code,
          onVerified: () => _completeRegistration(
            first: first,
            last: last,
            middle: middle,
            suffix: suffix,
            email: email,
            password: password,
            phone: phone,
            // For incoming_college: school = SHS school, course = SHS strand
            // planned_university and planned_courses are saved separately
            school: school,
            course: course,
            yearLevel: isIncoming ? null : _selectedYearLevel,
            eduLevel: _selectedEduLevel ?? 'college',
            plannedUniversity: isIncoming ? _plannedUniversityController.text.trim() : null,
            plannedCourses: isIncoming
                ? _plannedCoursesControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
                : null,
          ),
          onResendRequested: () async {
            // Regenerate and resend
            code = (100000 + random.nextInt(900000)).toString();
            await _sendEmailJSVerification(
              toName: first,
              toEmail: email,
              code: code,
            );
            _showSnackBar('Verification code resent.', isError: false);
          },
        );
      },
    );
  }

  Future<void> _completeRegistration({
    required String first,
    required String last,
    required String middle,
    required String suffix,
    required String email,
    required String password,
    required String phone,
    required String school,
    required String course,
    int? yearLevel,
    required String eduLevel,
    String? plannedUniversity,
    List<String>? plannedCourses,
  }) async {
    setState(() => _isLoading = true);
    try {
      // 1. Sign up user in Supabase Auth passing metadata (database trigger creates profile in public.users)
      final AuthResponse authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': first,
          'last_name': last,
          'role': 'scholar',
        },
      );

      final String? userId = authResponse.user?.id;
      if (userId == null) {
        throw const AuthException('Registration authentication failed.');
      }

      // Auto sign-in fallback if signUp does not establish active session automatically
      if (authResponse.session == null) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      // 2. Explicitly insert scholar details into public.scholar table
      await Supabase.instance.client.from('scholar').insert({
        'user_id': userId,
        'first_name': first,
        'last_name': last,
        'middle_name': middle.isNotEmpty ? middle : null,
        'suffix': suffix.isNotEmpty ? suffix : null,
        'birth_date': _selectedBirthDate?.toIso8601String().substring(0, 10),
        'gender': _selectedGender,
        'phone': phone,
        'school': school,
        'course': course,
        if (yearLevel != null) 'year_level': yearLevel,
        'education_level': eduLevel,
        if (plannedUniversity != null) 'planned_university': plannedUniversity,
        if (plannedCourses != null && plannedCourses.isNotEmpty) 'planned_courses': plannedCourses,
      });

      if (!mounted) return;
      _showSnackBar('Registration successful! Welcome to IskolarAko, $first.', isError: false);
      AuditLogService.createAuditLog(action: 'REGISTER / SIGNUP', target: 'Scholar: $first $last');
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false);
    } on AuthException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Failed to complete scholar profile setup.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Header/Title ──────────────────────────────────
              FadeTransition(
                opacity: _logoFade,
                child: SlideTransition(
                  position: _logoSlide,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3D2F),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(36),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_currentStep > 1) {
                                  _prevStep();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.chevronLeft,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.userPlus, color: Color(0xFFF59E0B), size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'SCHOLAR ENROLLMENT',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFF59E0B),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Create Account',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), width: 1),
                              ),
                              child: SvgPicture.asset(
                                'assets/logo/iskolarakologo-notext.svg',
                                height: 28,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFFF59E0B),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Step status indicator
                        _buildStepIndicator(),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Active Step Body ──────────────────────────────
              FadeTransition(
                opacity: _formFade,
                child: SlideTransition(
                  position: _formSlide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.1, 0.0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: _currentStep == 1
                              ? _buildStep1()
                              : _currentStep == 2
                                  ? _buildStep2()
                                  : _buildStep3(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepStatusDot(1),
              _buildStepStatusLine(1),
              _buildStepStatusDot(2),
              _buildStepStatusLine(2),
              _buildStepStatusDot(3),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep == 1
                ? 'Step 1 of 3: Account Info'
                : _currentStep == 2
                    ? 'Step 2 of 3: Personal Profile'
                    : 'Step 3 of 3: Academic Profile',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepStatusDot(int stepNum) {
    final isActive = _currentStep == stepNum;
    final isDone = _currentStep > stepNum;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? const Color(0xFFE8A838)
            : isActive
                ? Colors.white
                : Colors.white.withAlpha(50),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, size: 13, color: AppColors.primaryDark)
            : Text(
                '$stepNum',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.primaryDark : Colors.white70,
                ),
              ),
      ),
    );
  }

  Widget _buildStepStatusLine(int currentDotStep) {
    final isDone = _currentStep > currentDotStep;
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDone ? const Color(0xFFE8A838) : Colors.white.withAlpha(40),
    );
  }

  // ── Step 1: Account Info ──────────────────────────────────
  Widget _buildStep1() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Account Credentials',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 18),
        _buildField(
          label: 'Email Address',
          controller: _emailController,
          icon: LucideIcons.mail,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Password',
          controller: _passwordController,
          visible: _isPasswordVisible,
          onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Confirm Password',
          controller: _confirmPasswordController,
          visible: _isConfirmVisible,
          onToggle: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
          hint: 'Confirm security password',
          onChanged: (_) => setState(() {}),
        ),
        // Password validation feedback container
        if (_passwordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPasswordFeedbackPanel(),
        ],
        const SizedBox(height: 32),
        CustomButton(
          text: 'Next Step',
          onPressed: _nextStep,
        ),
        const SizedBox(height: 24),
        // Google Signup Option only
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.rule)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or sign up with',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.rule)),
          ],
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            _showSnackBar('Google Sign-In is not configured yet.', isError: true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.rule, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.chrome, color: Color(0xFFDB4437), size: 18),
                const SizedBox(width: 10),
                Text(
                  'Continue with Google',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Personal Info ──────────────────────────────────
  Widget _buildStep2() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Personal Profile Info',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildField(
                label: 'First Name *',
                controller: _firstNameController,
                icon: LucideIcons.user,
                hint: 'Juan',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                label: 'Last Name *',
                controller: _lastNameController,
                icon: LucideIcons.user,
                hint: 'Dela Cruz',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildField(
                label: 'Middle Name',
                controller: _middleNameController,
                icon: LucideIcons.user,
                hint: 'Maria',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                label: 'Suffix',
                controller: _suffixController,
                icon: LucideIcons.bookmark,
                hint: 'Jr.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildField(
          label: 'Phone Number *',
          controller: _phoneController,
          icon: LucideIcons.phone,
          hint: 'e.g. +63 912 345 6789',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 4,
              child: _buildDatePickerField(),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildGenderDropdownField(),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                child: Text('Back', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Next Step',
                onPressed: _nextStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Academic details ────────────────────────────────────

  Widget _buildStep3() {
    final isIncoming = _selectedEduLevel == 'incoming_college';

    // Year level options per education level
    final Map<String, List<Map<String, dynamic>>> yearOptions = {
      'college':    [1,2,3,4,5].map((y) => {'val': y, 'label': 'Year $y'}).toList(),
      'graduate':   [1,2,3,4].map((y) => {'val': y, 'label': 'Year $y'}).toList(),
      'senior_high':[{'val': 11, 'label': 'Grade 11'}, {'val': 12, 'label': 'Grade 12'}],
      'high_school':[7,8,9,10].map((y) => {'val': y, 'label': 'Grade $y'}).toList(),
      'elementary': [1,2,3,4,5,6].map((y) => {'val': y, 'label': 'Grade $y'}).toList(),
      'vocational': [{'val': 1, 'label': 'Semester 1'}, {'val': 2, 'label': 'Semester 2'}, {'val': 3, 'label': 'Semester 3'}],
      'incoming_college': [],
    };
    final currentYearOptions = yearOptions[_selectedEduLevel ?? 'college'] ?? yearOptions['college']!;

    final Map<String, String> schoolLabel = {
      'college': 'University / College Name *',
      'graduate': 'University / Graduate School Name *',
      'senior_high': 'Senior High School Name *',
      'high_school': 'Junior High School Name *',
      'elementary': 'Elementary School Name *',
      'vocational': 'TVET / Vocational School Name *',
      'incoming_college': 'Current SHS School Name *',
    };
    final Map<String, String> courseLabel = {
      'college': 'Course / Major *',
      'graduate': 'Degree Program *',
      'senior_high': 'Track & Strand * (e.g. STEM, ABM)',
      'high_school': 'Section / Track (optional)',
      'elementary': 'Grade Section (optional)',
      'vocational': 'TVET Program / NC Level *',
      'incoming_college': 'SHS Strand * (e.g. STEM, ABM, HUMSS)',
    };

    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Academic Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 18),

        // ── Education Level ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Education Level *',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.rule, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedEduLevel,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
                  items: const [
                    DropdownMenuItem(value: 'college',          child: Text('🎓 College / Undergraduate')),
                    DropdownMenuItem(value: 'graduate',         child: Text('🏛️ Graduate Studies (MA/PhD)')),
                    DropdownMenuItem(value: 'senior_high',      child: Text('📚 Senior High School (SHS)')),
                    DropdownMenuItem(value: 'high_school',      child: Text('🏫 High School (JHS)')),
                    DropdownMenuItem(value: 'elementary',       child: Text('🔖 Elementary')),
                    DropdownMenuItem(value: 'vocational',       child: Text('🔧 Vocational / TVET')),
                    DropdownMenuItem(value: 'incoming_college', child: Text('🌟 Incoming College (Graduating SHS)')),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedEduLevel = val;
                    _selectedYearLevel = null;
                  }),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── School name (label changes per level) ──
        _buildField(
          label: schoolLabel[_selectedEduLevel] ?? 'School Name *',
          controller: _schoolController,
          icon: LucideIcons.graduationCap,
          hint: isIncoming ? 'e.g. Pasig City Science High School' : 'School / University name',
        ),
        const SizedBox(height: 16),

        // ── Course / Strand / Program (label changes per level) ──
        _buildField(
          label: courseLabel[_selectedEduLevel] ?? 'Course / Strand *',
          controller: _courseController,
          icon: LucideIcons.bookOpen,
          hint: isIncoming ? 'e.g. STEM' : 'e.g. BS Computer Science',
        ),
        const SizedBox(height: 16),

        // ── Incoming College: Planned University + Course Choices ──
        if (isIncoming) ...[
          _buildField(
            label: 'Planned University / College *',
            controller: _plannedUniversityController,
            icon: LucideIcons.mapPin,
            hint: 'e.g. University of the Philippines Diliman',
          ),
          const SizedBox(height: 12),
          Text(
            'PREFERRED COURSES (up to 3)',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildField(
              label: 'Choice ${i + 1}${i == 0 ? ' *' : ''}',
              controller: _plannedCoursesControllers[i],
              icon: LucideIcons.star,
              hint: 'e.g. BS Computer Science',
            ),
          )),
          const SizedBox(height: 4),
        ],

        // ── Year / Grade Level ──
        if (!isIncoming) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentYearOptions.isEmpty ? 'Year / Grade Level' : 'Year / Grade Level *',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.rule, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedYearLevel,
                    hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
                    items: currentYearOptions.map((opt) {
                      return DropdownMenuItem<int>(
                        value: opt['val'] as int,
                        child: Text(opt['label'] as String, style: GoogleFonts.inter(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedYearLevel = val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Terms checkbox
        GestureDetector(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _agreedToTerms ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _agreedToTerms ? AppColors.primary : AppColors.rule,
                    width: 1.5,
                  ),
                ),
                child: _agreedToTerms
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: 'I agree to the ',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms and Conditions',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                child: Text('Back', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Submit Info',
                isLoading: _isLoading,
                onPressed: _handleRegister,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggle,
    String hint = '••••••••',
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !visible,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(LucideIcons.lock, size: 16, color: AppColors.textSecondary),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                visible ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    final birthDateStr = _selectedBirthDate == null
        ? 'Select date'
        : '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Birth Date *',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: _selectedBirthDate ?? DateTime(2005),
              firstDate: DateTime(1980),
              lastDate: now,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedDate != null) {
              setState(() {
                _selectedBirthDate = pickedDate;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rule, width: 1),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Text(
                  birthDateStr,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: _selectedBirthDate == null ? AppColors.textMuted : AppColors.textPrimary,
                    fontWeight: _selectedBirthDate == null ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.rule, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              hint: Text('Select', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
              icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              dropdownColor: AppColors.surface,
              onChanged: (String? val) {
                setState(() {
                  _selectedGender = val;
                });
              },
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
                DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildPasswordFeedbackPanel() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Checks
    final hasCapital = password.contains(RegExp(r'[A-Z]'));
    final hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasMinLength = password.length >= 6;

    // Strength score
    int score = 0;
    if (hasCapital) score++;
    if (hasSpecial) score++;
    if (hasNumber) score++;
    if (hasMinLength) score++;

    String strengthText = 'Weak';
    Color strengthColor = AppColors.error;
    if (score == 0) {
      strengthText = 'None';
      strengthColor = AppColors.textMuted;
    } else if (score == 4) {
      strengthText = 'Strong';
      strengthColor = AppColors.primary;
    } else if (score >= 2) {
      strengthText = 'Medium';
      strengthColor = AppColors.amber;
    }

    final isMatching = confirmPassword.isNotEmpty && password == confirmPassword;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rule.withAlpha(120), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strength status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password Strength:',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: strengthColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  strengthText,
                  style: GoogleFonts.inter(fontSize: 11, color: strengthColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Checklist
          _buildChecklistItem('One capital letter [A-Z]', hasCapital),
          const SizedBox(height: 6),
          _buildChecklistItem('One special character (!@#\$)', hasSpecial),
          const SizedBox(height: 6),
          _buildChecklistItem('One number [0-9]', hasNumber),
          const SizedBox(height: 6),
          _buildChecklistItem('At least 6 characters', hasMinLength),
          
          if (confirmPassword.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: AppColors.rule, height: 1),
            ),
            Row(
              children: [
                Icon(
                  isMatching ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
                  color: isMatching ? AppColors.primary : AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isMatching ? 'Passwords match' : 'Passwords do not match',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isMatching ? AppColors.primary : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          color: isMet ? AppColors.primary : AppColors.textMuted,
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: isMet ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isMet ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _OtpVerificationSheet extends StatefulWidget {
  final String email;
  final String verificationCode;
  final VoidCallback onVerified;
  final VoidCallback onResendRequested;

  const _OtpVerificationSheet({
    required this.email,
    required this.verificationCode,
    required this.onVerified,
    required this.onResendRequested,
  });

  @override
  State<_OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<_OtpVerificationSheet> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  String? _errorMessage;
  int _timerSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNode.requestFocus();
    });
  }

  void _startTimer() {
    setState(() {
      _timerSeconds = 30;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _canResend = true;
        }
      });
      return _timerSeconds > 0;
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _onVerify() {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits.';
      });
      return;
    }

    if (code == widget.verificationCode) {
      Navigator.pop(context);
      widget.onVerified();
    } else {
      setState(() {
        _errorMessage = 'Incorrect verification code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Verify Email',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit verification code to\n${widget.email}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          GestureDetector(
            onTap: () => _otpFocusNode.requestFocus(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hidden single TextField capturing keystrokes and paste
                Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (_errorMessage != null) _errorMessage = null;
                      });
                      if (value.length == 6) {
                        _onVerify();
                      }
                    },
                  ),
                ),
                // 6 Separated Visual Number Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final text = _otpController.text;
                    final isFilled = index < text.length;
                    final char = isFilled ? text[index] : '';
                    final isFocused = _otpFocusNode.hasFocus &&
                        (index == text.length || (index == 5 && text.length == 6));

                    return Container(
                      width: 44,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isFilled || isFocused ? Colors.white : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? AppColors.primary
                              : isFilled
                                  ? AppColors.primaryDark.withValues(alpha: 0.6)
                                  : AppColors.rule,
                          width: isFocused ? 2.0 : 1.2,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: isFilled
                          ? Text(
                              char,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : isFocused
                              ? Container(
                                  width: 2,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                )
                              : Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.rule,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          CustomButton(
            text: 'Verify Code',
            onPressed: _onVerify,
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _canResend ? "Didn't receive code? " : "Resend code in ",
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              _canResend
                  ? GestureDetector(
                      onTap: () {
                        widget.onResendRequested();
                        _startTimer();
                      },
                      child: Text(
                        'Resend',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Text(
                      '${_timerSeconds}s',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
