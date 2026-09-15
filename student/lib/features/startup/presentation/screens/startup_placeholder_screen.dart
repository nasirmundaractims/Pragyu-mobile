import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/config/app_config.dart';

/// Internal holding screen after S-01.
/// Not S-02 Welcome — waiting for approval before implementing auth entry.
class StartupPlaceholderScreen extends StatelessWidget {
  const StartupPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                config.appName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Student app foundation is ready.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brandSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'S-01 Splash complete',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Environment: ${config.environment.name}\n'
                      'API: ${config.apiBaseUrl}\n\n'
                      'Stopped before S-02 Welcome. Awaiting approval.',
                      style: const TextStyle(
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
