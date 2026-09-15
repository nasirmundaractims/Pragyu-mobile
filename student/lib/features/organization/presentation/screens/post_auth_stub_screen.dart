import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// Holding screen after S-05 org selection. S-06 Onboarding tips is next.
class PostAuthStubScreen extends StatelessWidget {
  const PostAuthStubScreen({super.key});

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
                'You’re in',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'S-05 Institute picker is complete. Your active organization '
                'is saved for API calls (X-Organization-Id).\n\n'
                'Next up: S-06 Onboarding tips (optional), then Home.',
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
