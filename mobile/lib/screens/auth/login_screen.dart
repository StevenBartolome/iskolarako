import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/services/audit_log_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  late final AnimationController _heroController;
  late final AnimationController _formController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
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

    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
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
    Future.delayed(const Duration(milliseconds: 300), () {
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
      _showSnackBar('Please fill in all fields to sign in.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('[Login] Attempting sign-in for: "$email"');

    try {
      final AuthResponse response = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

      final user = response.user;
      if (user == null) {
        throw const AuthException('Authentication failed: No user returned.');
      }

      // Purge oversized metadata if present (to avoid JWT header overflow)
      if (user.userMetadata != null) {
        final Map<String, dynamic> cleanData = {};
        bool hasOversized = false;
        user.userMetadata!.forEach((key, value) {
          if (value is String && (value.startsWith('data:image') || value.length > 1000)) {
            hasOversized = true;
            cleanData[key] = '';
          }
        });
        if (hasOversized) {
          try {
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: cleanData),
            );
            await Supabase.instance.client.auth.refreshSession();
          } catch (e) {
            debugPrint('[Login] Metadata purge info: $e');
          }
        }
      }

      final userId = user.id;
      Map<String, dynamic>? userData;
      try {
        userData = await Supabase.instance.client
            .from('users')
            .select('role, first_name, email')
            .eq('id', userId)
            .maybeSingle();
      } on PostgrestException catch (e) {
        debugPrint('[Login] User query note: ${e.message}');
      }

      String role = (userData?['role']?.toString().toLowerCase().trim() ??
              user.userMetadata?['role']?.toString().toLowerCase().trim() ??
              'scholar')
          .toLowerCase();
      String firstName = userData?['first_name']?.toString() ??
          user.userMetadata?['first_name']?.toString() ??
          'Scholar';

      // Auto-create missing user row if needed
      if (userData == null) {
        try {
          final newProfile = {
            'id': userId,
            'email': email,
            'first_name': firstName,
            'role': role.isNotEmpty ? role : 'scholar',
            'created_at': DateTime.now().toIso8601String(),
          };
          await Supabase.instance.client.from('users').upsert(newProfile);
          if (role.isEmpty) role = 'scholar';
        } catch (e) {
          debugPrint('[Login] Auto-create user row note: $e');
        }
      }

      // Check role permissions: scholars, students, and applicants are allowed
      if (role.isNotEmpty &&
          role != 'scholar' &&
          role != 'student' &&
          role != 'applicant') {
        await Supabase.instance.client.auth.signOut();
        throw AuthException('Access Denied: Mobile app is restricted to Scholars (current role: $role).');
      }

      if (!mounted) return;
      _showSnackBar('Welcome back, $firstName!', isError: false);
      AuditLogService.createAuditLog(action: 'LOGIN', target: 'Mobile App');
      Navigator.pushReplacementNamed(context, AppRouter.home);
    } on AuthException catch (e) {
      _showSnackBar(e.message, isError: true);
    } on PostgrestException catch (e) {
      _showSnackBar('Database error: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('Error signing in: $e', isError: true);
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
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFB91C1C) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.logOut,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Exit Application',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E3D2F),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to close IskoAko?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'No, Stay',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3D2F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Yes, Exit',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFCFA),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ── Interactive Hero Top Header Banner ───────────────
                FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E3D2F),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(36),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Portal Badge Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.shieldCheck, color: Color(0xFFF59E0B), size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  'SCHOLAR PORTAL ACCESS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFF59E0B),
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
  
                          // Static Elegant Logo Graphic
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: SvgPicture.asset(
                              'assets/logo/iskolarakologo-notext.svg',
                              height: 64,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFF59E0B),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
  
                          Text(
                            'IskoAko',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Empowering Filipino Scholars Everywhere',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
  
                // ── Interactive Animated Form Container ──────────────
                FadeTransition(
                  opacity: _formFade,
                  child: SlideTransition(
                    position: _formSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back!',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to access your scholarship applications & disbursements.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
  
                          // Email Address Input Field
                          _buildInputField(
                            label: 'Email Address',
                            controller: _emailController,
                            icon: LucideIcons.mail,
                            hint: 'your.name@student.edu.ph',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
  
                          // Password Input Field
                          _buildPasswordField(),
                          const SizedBox(height: 14),
  
                          // Remember Me & Forgot Password Options
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
                                        color: _rememberMe ? const Color(0xFF1E3D2F) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _rememberMe ? const Color(0xFF1E3D2F) : const Color(0xFFD1D5DB),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: _rememberMe
                                          ? const Icon(LucideIcons.check, size: 13, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remember me',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _showSnackBar('Contact your scholarship coordinator to reset password.', isError: false);
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E3D2F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
  
                          // Interactive Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleLogin,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(LucideIcons.logIn, size: 18),
                              label: Text(
                                _isLoading ? 'Authenticating...' : 'Sign In to Portal',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3D2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
  
                          // Divider line
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'New to IskoAko?',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                            ],
                          ),
                          const SizedBox(height: 20),
  
                          // Register Navigation Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRouter.register);
                              },
                              icon: const Icon(LucideIcons.userPlus, size: 16, color: Color(0xFF1E3D2F)),
                              label: Text(
                                'Create Scholar Account',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E3D2F),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      ),
    );
  }

  // ─── Input Field Component ──────────────────────────────────────────────────
  Widget _buildInputField({
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1E3D2F), width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Password Field Component ───────────────────────────────────────────────
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(LucideIcons.lock, size: 18, color: Color(0xFF6B7280)),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isPasswordVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                  key: ValueKey(_isPasswordVisible),
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1E3D2F), width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
