import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/theme/student_hub_colors.dart';

/// Shared secondary-route header for the Student App (hub chrome).
///
/// Back + page title only — matches Learn / Practice / Me secondary screens.
/// Uses [Icons.arrow_back_rounded] so every route shares the same back control.
class StudentAppHeader extends StatelessWidget {
  const StudentAppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.showBack = true,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  /// When false, hides the back control even if the route can pop.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final canPop =
        showBack && (onBack != null || Navigator.of(context).canPop());
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: StudentHubColors.ink,
              ),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: StudentHubColors.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

/// Soft page scaffold shell used by secondary Student App routes.
class StudentHubPage extends StatelessWidget {
  const StudentHubPage({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions,
    this.showBack = true,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentHubColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            StudentAppHeader(
              title: title,
              onBack: onBack,
              actions: actions,
              showBack: showBack,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
