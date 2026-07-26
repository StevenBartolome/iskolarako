import 'package:flutter/material.dart';
import 'package:iskoako/widgets/custom_button.dart';
import 'package:iskoako/widgets/custom_text_field.dart';


class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CustomTextField(
              label: 'Full Name',
              hint: 'Juan Dela Cruz',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            const CustomTextField(
              label: 'Email',
              hint: 'juan@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),
            const CustomTextField(
              label: 'Student ID',
              hint: '2023-XXXXX',
              prefixIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            const CustomTextField(
              label: 'Password',
              hint: 'Create a strong password',
              isPassword: true,
              prefixIcon: Icons.lock_outline,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Register',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
