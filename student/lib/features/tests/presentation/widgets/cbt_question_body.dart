import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
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
    this.markedForReview = false,
    this.onReviewLater,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
  final bool markedForReview;
  final VoidCallback? onReviewLater;
  final EdgeInsetsGeometry padding;

  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _green = Color(0xFF22A06B);
  static const _greenSoft = Color(0xFFE8F8EF);
  static const _orangeSoft = Color(0xFFFFF1E0);
  static const _orange = Color(0xFFC47A1A);

  @override
  Widget build(BuildContext context) {
    final kind = question.kind;
    final choices = question.effectiveChoices;
    final passage = question.passageHtml?.trim();

    return ListView(
      padding: padding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Question ${index + 1} of $total',
                softWrap: true,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            if (onReviewLater != null)
              TextButton.icon(
                onPressed: onReviewLater,
                style: TextButton.styleFrom(
                  foregroundColor: _blue,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                icon: Icon(
                  markedForReview
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 18,
                ),
                label: Text(
                  markedForReview ? 'Marked' : 'Review Later',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              label: question.kindLabel,
              background: _orangeSoft,
              foreground: _orange,
            ),
            if (question.maxMarks != null)
              _Chip(
                label: '+${_formatMarks(question.maxMarks!)} marks',
                background: _greenSoft,
                foreground: _green,
              ),
          ],
        ),
        if (passage != null && passage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6EAF2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Passage',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 6),
                CbtRichContent(content: null, html: passage, compact: true),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
            height: 1.35,
          ),
          child: CbtRichContent(
            content: question.content ?? 'Question ${index + 1}',
            html: question.contentHtml,
          ),
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
                  errorBuilder: (_, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (kind == CbtQuestionKind.mcq || kind == CbtQuestionKind.trueFalse)
          ...List.generate(choices.length, (i) {
            final choice = choices[i];
            final selected = answer?.choiceId == choice.id;
            final letter = String.fromCharCode(65 + i);
            final labelLooksHtml = RegExp(
              r'<\/?[a-z][\s\S]*>',
              caseSensitive: false,
            ).hasMatch(choice.label);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: selected ? _blueSoft : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChoice(choice),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _blue : const Color(0xFFE6EAF2),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? _blue : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? _blue
                                  : const Color(0xFFC5CDD9),
                              width: 1.5,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$letter.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w800,
                            color: selected ? _blue : _ink,
                          ),
                        ),
                        const SizedBox(width: 6),
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
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: _muted,
              height: 1.45,
            ),
          ),
      ],
    );
  }

  static String _formatMarks(double marks) {
    if (marks == marks.roundToDouble()) return marks.round().toString();
    return marks.toString();
  }
}

extension on AssessmentQuestionPreview {
  String get kindLabel {
    switch (kind) {
      case CbtQuestionKind.mcq:
        return 'MCQ';
      case CbtQuestionKind.trueFalse:
        return 'True / False';
      case CbtQuestionKind.shortText:
        return 'Short answer';
      case CbtQuestionKind.essay:
        return 'Essay';
      case CbtQuestionKind.unsupported:
        return 'Question';
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
