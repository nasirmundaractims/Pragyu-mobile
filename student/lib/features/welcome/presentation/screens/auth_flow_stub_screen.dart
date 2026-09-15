import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// Holding screen after S-02 CTAs. Full auth screens (S-03+) are not built yet.
class AuthFlowStubScreen extends StatelessWidget {
  const AuthFlowStubScreen({
    super.key,
    required this.title,
    required this.nextScreenId,
  });

  final String title;
  final String nextScreenId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$nextScreenId is next',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This step opens when the next screen is approved and implemented.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
