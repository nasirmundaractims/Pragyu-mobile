import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';

/// Opens the question palette as a bottom sheet (phones / compact layout).
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
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height;
      return SafeArea(
        child: SizedBox(
          height: height * 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: CbtQuestionPalettePanel(
              questions: questions,
              currentId: currentId,
              answers: answers,
              player: player,
              onSelect: (index) {
                Navigator.of(context).pop();
                onSelect(index);
              },
            ),
          ),
        ),
      );
    },
  );
}

/// Inline or sheet palette with legend + numbered grid (Pragyu Test Attempt).
class CbtQuestionPalettePanel extends StatelessWidget {
  const CbtQuestionPalettePanel({
    super.key,
    required this.questions,
    required this.currentId,
    required this.answers,
    required this.player,
    required this.onSelect,
    this.scrollable = true,
  });

  final List<AssessmentQuestionPreview> questions;
  final String? currentId;
  final Map<String, StudentAnswerValue> answers;
  final CbtPlayerState player;
  final ValueChanged<int> onSelect;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final visited = player.visited.toSet();
    final marked = player.markedForReview.toSet();

    var answeredCount = 0;
    var notAttempted = 0;
    var markedOnly = 0;
    var answeredMarked = 0;
    for (final q in questions) {
      final key = q.answerKey;
      final isAnswered = answers[key]?.isAnswered ?? false;
      final isMarked = marked.contains(key);
      if (isAnswered && isMarked) {
        answeredMarked += 1;
      } else if (isMarked) {
        markedOnly += 1;
      } else if (isAnswered) {
        answeredCount += 1;
      } else {
        notAttempted += 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Question Palette',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B4C),
          ),
        ),
        const SizedBox(height: 12),
        _LegendRow(
          items: [
            (const Color(0xFF22A06B), 'Answered ($answeredCount)'),
            (const Color(0xFFD0D7E2), 'Not Attempted ($notAttempted)'),
            (const Color(0xFFE85D75), 'Marked for Review ($markedOnly)'),
            (const Color(0xFF7B5CFF), 'Answered & Marked ($answeredMarked)'),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            physics: scrollable
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              final status = paletteStatusFor(
                questionId: question.answerKey,
                currentId: currentId,
                visited: visited,
                marked: marked,
                answered: answers[question.answerKey]?.isAnswered ?? false,
              );
              return _PaletteTile(
                index: index + 1,
                status: status,
                onTap: () => onSelect(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.$1,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.$2,
                    softWrap: true,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5B6B7C),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.index,
    required this.status,
    required this.onTap,
  });

  final int index;
  final CbtPaletteStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
    return Material(
      color: style.$1,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: style.$2,
              width: status == CbtPaletteStatus.current ? 2 : 1,
            ),
          ),
          child: Text(
            '$index',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: style.$3,
            ),
          ),
        ),
      ),
    );
  }

  static (Color, Color, Color) _styleFor(CbtPaletteStatus status) {
    switch (status) {
      case CbtPaletteStatus.current:
        return (
          const Color(0xFFE8F1FF),
          const Color(0xFF2F7BFF),
          const Color(0xFF2F7BFF),
        );
      case CbtPaletteStatus.answered:
        return (
          const Color(0xFFE6F7F1),
          const Color(0xFFB7E5D3),
          const Color(0xFF22A06B),
        );
      case CbtPaletteStatus.answeredMarked:
        return (
          const Color(0xFFF3E9FF),
          const Color(0xFFD4C2FF),
          const Color(0xFF7B5CFF),
        );
      case CbtPaletteStatus.marked:
        return (
          const Color(0xFFFDE8EC),
          const Color(0xFFF5C2CB),
          const Color(0xFFE85D75),
        );
      case CbtPaletteStatus.visited:
        return (
          const Color(0xFFF0F4FA),
          const Color(0xFFD7DEEA),
          const Color(0xFF1A2B4C),
        );
      case CbtPaletteStatus.notVisited:
        return (Colors.white, const Color(0xFFD7DEEA), AppColors.muted);
    }
  }
}
