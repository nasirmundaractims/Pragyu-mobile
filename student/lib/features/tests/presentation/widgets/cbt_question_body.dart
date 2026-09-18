import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/presentation/widgets/cbt_rich_content.dart';
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
    final passage = question.passageHtml?.trim();

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
        if (passage != null && passage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brandSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Passage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                CbtRichContent(content: null, html: passage, compact: true),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        CbtRichContent(
          content: question.content ?? 'Question ${index + 1}',
          html: question.contentHtml,
        ),
        if (question.mediaUrls.isNotEmpty ||
            extractHtmlImageUrls(question.contentHtml).isNotEmpty) ...[
          const SizedBox(height: 12),
          ...{
            ...question.mediaUrls,
            ...extractHtmlImageUrls(question.contentHtml),
            ...extractHtmlImageUrls(question.passageHtml),
          }.map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
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
            final labelLooksHtml = RegExp(
              r'<\/?[a-z][\s\S]*>',
              caseSensitive: false,
            ).hasMatch(choice.label);
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          child: CbtRichContent(
                            content: choice.label,
                            html: labelLooksHtml ? choice.label : null,
                            compact: true,
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
