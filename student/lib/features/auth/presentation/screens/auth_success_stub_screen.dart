import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// Holding screen after successful S-03 sign-in. S-05 Org picker is next.
class AuthSuccessStubScreen extends StatelessWidget {
  const AuthSuccessStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 32),
              Text(
                'Signed in',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'S-03 Sign in is complete. Session tokens are stored securely.\n\n'
                'Next up: S-05 Organization / institute picker.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
