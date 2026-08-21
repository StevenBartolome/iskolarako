import 'package:flutter/material.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

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
      duration: const Duration(milliseconds: 900),
    );

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));

    _formFade = CurvedAnimation(parent: _formController, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      _heroController.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      _formController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _heroController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('\n========================================');
    debugPrint('[Login] Attempting login for: "$email"');
    debugPrint('========================================');

    try {
      final AuthResponse response = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

      final user = response.user;
      if (user == null) {
        throw const AuthException('Authentication failed: No user returned.');
      }

      debugPrint('[Login] Supabase Auth Response received:');
      debugPrint('  - User ID: ${user.id}');
      debugPrint('  - Email: ${user.email}');
      debugPrint('  - Confirmed At: ${user.emailConfirmedAt}');

      // Detect and purge oversized fields (e.g. base64 avatar images) from user_metadata to fix the 100KB JWT header overflow
      if (user.userMetadata != null) {
        final Map<String, dynamic> cleanData = {};
        bool hasOversized = false;
        user.userMetadata!.forEach((key, value) {
          if (value is String && (value.startsWith('data:image') || value.length > 1000)) {
            hasOversized = true;
            cleanData[key] = ''; // Using empty string instead of null to prevent GoTrue 500 error
            debugPrint('[Login] Found oversized field in user_metadata: "$key" (${value.length} chars). Overwriting with empty string...');
          }
        });
        if (hasOversized) {
          try {
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: cleanData),
            );
            debugPrint('[Login] Successfully purged oversized metadata from auth user record!');
            // Refresh session so Supabase client gets a clean <1KB JWT
            await Supabase.instance.client.auth.refreshSession();
            debugPrint('[Login] Session refreshed with clean JWT.');
          } catch (e) {
            debugPrint('[Login] Warning during metadata purge: $e');
          }
        }
      }

      final userId = user.id;

      // Query public.users table with maybeSingle to prevent crash if record is missing
      debugPrint('[Login] Fetching public.users row for ID: $userId ...');
      Map<String, dynamic>? userData;
      try {
        userData = await Supabase.instance.client
            .from('users')
            .select('role, first_name, email')
            .eq('id', userId)
            .maybeSingle();
      } on PostgrestException catch (e) {
        debugPrint('[Login] PostgrestException on user query: ${e.message}');
        if (e.message.contains('100KB') || e.message.contains('header buffer size')) {
          debugPrint('[Login] 100KB Header overflow detected on query. Performing emergency metadata cleanup and session refresh...');
          try {
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'avatar_url': ''}),
            );
            await Supabase.instance.client.auth.refreshSession();
            userData = await Supabase.instance.client
                .from('users')
                .select('role, first_name, email')
                .eq('id', userId)
                .maybeSingle();
          } catch (err) {
            debugPrint('[Login] Emergency refresh error: $err');
          }
        }
      }

      debugPrint('[Login] public.users query result: $userData');

      String role = (userData?['role']?.toString().toLowerCase().trim() ??
              user.userMetadata?['role']?.toString().toLowerCase().trim() ??
              'scholar')
          .toLowerCase();
      String firstName = userData?['first_name']?.toString() ??
          user.userMetadata?['first_name']?.toString() ??
          'Scholar';

      debugPrint('[Login] Extracted Role: "$role", First Name: "$firstName"');

      // If user profile is missing from public.users table, attempt auto-creation
      if (userData == null) {
        debugPrint('[Login] Note: Profile row not found in public.users table. Attempting auto-creation...');
        try {
          final newProfile = {
            'id': userId,
            'email': email,
            'first_name': firstName,
            'role': role.isNotEmpty ? role : 'scholar',
            'created_at': DateTime.now().toIso8601String(),
          };
          await Supabase.instance.client.from('users').upsert(newProfile);
          debugPrint('[Login] Successfully created missing public.users row!');
          if (role.isEmpty) role = 'scholar';
        } catch (e) {
          debugPrint('[Login] Auto-create public.users row failed (non-fatal): $e');
        }
      }

      // Check role permissions: scholars, students, and applicants are allowed
      if (role.isNotEmpty &&
          role != 'scholar' &&
          role != 'student' &&
          role != 'applicant') {
        debugPrint('[Login] ACCESS DENIED: Account role is "$role". Only scholars can use the mobile app.');
        await Supabase.instance.client.auth.signOut();
        throw AuthException('Access Denied: Only scholars can use this app (current role: $role).');
      }

      if (!mounted) return;
      debugPrint('[Login] Login successful! Navigating to Home...');
      _showSnackBar('Welcome back, $firstName!', isError: false);
      Navigator.pushReplacementNamed(context, AppRouter.home);
    } on AuthException catch (e) {
      debugPrint('[Login] AuthException: ${e.message} (Status code: ${e.statusCode})');
      _showSnackBar(e.message, isError: true);
    } on PostgrestException catch (e) {
      debugPrint('[Login] PostgrestException: ${e.message} (Code: ${e.code}, Details: ${e.details}, Hint: ${e.hint})');
      _showSnackBar('Database error: ${e.message}', isError: true);
    } catch (e, stackTrace) {
      debugPrint('[Login] Unexpected error during login: $e');
      debugPrint('[Login] StackTrace: $stackTrace');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Hero section (forest-green band) ──────────────
              FadeTransition(
                opacity: _logoFade,
                child: SlideTransition(
                  position: _logoSlide,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 40),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Logo
                        SvgPicture.asset(
                          'assets/logo/iskolarakologo-notext.svg',
                          height: 108,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFE8A838),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'IskolarAko',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Scholarship Management System',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withAlpha(160),
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Form section ──────────────────────────────────
              FadeTransition(
                opacity: _formFade,
                child: SlideTransition(
                  position: _formSlide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue your scholarship journey.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Email field
                        _buildField(
                          label: 'Email Address',
                          controller: _emailController,
                          icon: LucideIcons.mail,
                          hint: 'you@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        _buildPasswordField(),
                        const SizedBox(height: 12),

                        // Remember me + Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _rememberMe = !_rememberMe),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _rememberMe ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _rememberMe ? AppColors.primary : AppColors.rule,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _rememberMe
                                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Remember me',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Login button
                        CustomButton(
                          text: 'Sign In',
                          isLoading: _isLoading,
                          onPressed: _handleLogin,
                        ),
                        const SizedBox(height: 24),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppColors.rule)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'or continue with',
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

                        // Social icons - Google Only
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GestureDetector(
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Register link
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRouter.register),
                            child: RichText(
                              text: TextSpan(
                                text: "Don't have an account?  ",
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Create one',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
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
              ),
            ],
          ),
        ),
      ),
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
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13.5),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13.5),
            prefixIcon: const Icon(LucideIcons.lock, size: 18, color: AppColors.textSecondary),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              child: Icon(
                _isPasswordVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rule, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
