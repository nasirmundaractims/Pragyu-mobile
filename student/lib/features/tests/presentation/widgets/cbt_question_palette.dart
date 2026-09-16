import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';

Future<void> showCbtPaletteSheet({
  required BuildContext context,
  required List<AssessmentQuestionPreview> questions,
  required String? currentId,
  required Map<String, StudentAnswerValue> answers,
  required CbtPlayerState player,
  required ValueChanged<int> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final visited = player.visited.toSet();
      final marked = player.markedForReview.toSet();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Question palette',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < questions.length; i++)
                    _PaletteChip(
                      index: i + 1,
                      status: paletteStatusFor(
                        questionId: questions[i].answerKey,
                        currentId: currentId,
                        visited: visited,
                        marked: marked,
                        answered:
                            answers[questions[i].answerKey]?.isAnswered ??
                                false,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(i);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _Legend(color: AppColors.brand, label: 'Current'),
                  _Legend(color: Color(0xFF1F8A5B), label: 'Answered'),
                  _Legend(color: Color(0xFFC0392B), label: 'Marked'),
                  _Legend(color: AppColors.muted, label: 'Not visited'),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.index,
    required this.status,
    required this.onTap,
  });

  final int index;
  final CbtPaletteStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status);
    return Material(
      color: colors.$1,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.$2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static (Color, Color) _colorsFor(CbtPaletteStatus status) {
    switch (status) {
      case CbtPaletteStatus.current:
        return (AppColors.brand, Colors.white);
      case CbtPaletteStatus.answered:
      case CbtPaletteStatus.answeredMarked:
        return (const Color(0xFFE6F5EE), AppColors.success);
      case CbtPaletteStatus.marked:
        return (const Color(0xFFFDECEC), AppColors.danger);
      case CbtPaletteStatus.visited:
        return (AppColors.brandSoft, AppColors.brand);
      case CbtPaletteStatus.notVisited:
        return (AppColors.surface, AppColors.muted);
    }
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}
