import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/presentation/widgets/cbt_subjective_answer_panel.dart';

class CbtQuestionBody extends StatelessWidget {
  const CbtQuestionBody({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.answer,
    required this.onChoice,
    required this.onTextChanged,
    this.onAddImages,
    this.onRemoveImage,
    this.isUploading = false,
    this.uploadProgress = 0,
  });

  final AssessmentQuestionPreview question;
  final int index;
  final int total;
  final StudentAnswerValue? answer;
  final ValueChanged<AnswerChoice> onChoice;
  final ValueChanged<String> onTextChanged;
  final VoidCallback? onAddImages;
  final ValueChanged<String>? onRemoveImage;
  final bool isUploading;
  final int uploadProgress;

  @override
  Widget build(BuildContext context) {
    final kind = question.kind;
    final choices = question.effectiveChoices;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Question ${index + 1} of $total',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          question.content ?? 'Question ${index + 1}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            height: 1.4,
          ),
        ),
        if (question.maxMarks != null) ...[
          const SizedBox(height: 8),
          Text(
            '${_formatMarks(question.maxMarks!)} marks',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        if (kind == CbtQuestionKind.mcq || kind == CbtQuestionKind.trueFalse)
          ...choices.map((choice) {
            final selected = answer?.choiceId == choice.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: selected
                    ? AppColors.brandSoft
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChoice(choice),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.brand
                            : AppColors.brandSoft,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? AppColors.brand
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            choice.label,
                            style: const TextStyle(
                              color: AppColors.ink,
                              height: 1.4,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          })
        else if (kind == CbtQuestionKind.shortText ||
            kind == CbtQuestionKind.essay)
          CbtSubjectiveAnswerPanel(
            question: question,
            kind: kind,
            answer: answer,
            onTextChanged: onTextChanged,
            onAddImages: onAddImages,
            onRemoveImage: onRemoveImage,
            isUploading: isUploading,
            uploadProgress: uploadProgress,
          )
        else
          const Text(
            'This question type is not supported in the mobile player yet. You can still mark it for review and submit.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
      ],
    );
  }

  static String _formatMarks(double marks) {
    if (marks == marks.roundToDouble()) return marks.round().toString();
    return marks.toString();
  }
}
