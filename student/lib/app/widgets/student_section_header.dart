import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/theme/student_hub_colors.dart';

/// Shared section title used across Student App hubs and secondary screens.
///
/// Matches Home / Learn / Practice: 18 / w800 ink title + optional trailing
/// text action (e.g. "See All").
class StudentSectionHeader extends StatelessWidget {
  const StudentSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.leading,
    this.compact = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? leading;

  /// Slightly smaller title (16 / w700) for dense secondary lists.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasAction =
        actionLabel != null && actionLabel!.trim().isNotEmpty && onAction != null;

    return Row(
      children: [
        if (leading != null) ...[
          Icon(leading, size: compact ? 18 : 20, color: StudentHubColors.blue),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: compact ? 16 : 18,
              fontWeight: compact ? FontWeight.w700 : FontWeight.w800,
              color: StudentHubColors.ink,
            ),
          ),
        ),
        if (hasAction)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: StudentHubColors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
