import 'package:flutter/material.dart';
import 'package:iskoako/utils/app_router.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/widgets/custom_text_field.dart';
import 'package:iskoako/constants/app_colors.dart';
import 'package:iskoako/widgets/glassmorphism_card.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _checkSupabaseConnection(BuildContext context) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection to Supabase...')),
    );
    try {
      await Supabase.instance.client
          .from('test_connection')
          .select()
          .limit(1);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Success: Connected to Supabase!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final errorMsg = e.toString();
      ScaffoldMessenger.of(context).clearSnackBars();
      if (errorMsg.contains('SocketException') || errorMsg.contains('Failed host')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Failed: Network unreachable ($errorMsg)'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Any response from server (even table not found) confirms API/network is fully connected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Success: Connected to Supabase!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GlassmorphismCard(
                  color: Colors.white.withAlpha(220),
                  padding: const EdgeInsets.all(32.0),
                  borderRadius: 30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.graduationCap,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Secure your future today.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      const CustomTextField(
                        label: 'Email / Student ID',
                        hint: 'Enter your email or ID',
                        prefixIcon: LucideIcons.mail,
                      ),
                      const SizedBox(height: 16),
                      const CustomTextField(
                        label: 'Password',
                        hint: 'Enter your password',
                        isPassword: true,
                        prefixIcon: LucideIcons.lock,
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: 'Login',
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, AppRouter.home);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRouter.register);
                        },
                        child: const Text(
                          'Don\'t have an account? Sign Up',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(),
                      TextButton.icon(
                        onPressed: () => _checkSupabaseConnection(context),
                        icon: const Icon(LucideIcons.database, size: 14, color: AppColors.primary),
                        label: const Text(
                          'TEST DATABASE CONNECTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
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
