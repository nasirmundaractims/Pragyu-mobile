import 'package:flutter/material.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';

class CbtSubjectiveAnswerPanel extends StatelessWidget {
  const CbtSubjectiveAnswerPanel({
    super.key,
    required this.question,
    required this.kind,
    required this.answer,
    required this.onTextChanged,
    this.onAddImages,
    this.onRemoveImage,
    this.isUploading = false,
    this.uploadProgress = 0,
  });

  final AssessmentQuestionPreview question;
  final CbtQuestionKind kind;
  final StudentAnswerValue? answer;
  final ValueChanged<String> onTextChanged;
  final VoidCallback? onAddImages;
  final ValueChanged<String>? onRemoveImage;
  final bool isUploading;
  final int uploadProgress;

  @override
  Widget build(BuildContext context) {
    final text = answer?.text ?? '';
    final wordCount = _countWords(text);
    final wordLimit = question.wordLimit;
    final isEssay = kind == CbtQuestionKind.essay;
    final images = answer?.images ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('${question.answerKey}-text'),
          initialValue: text,
          minLines: isEssay ? 8 : 4,
          maxLines: isEssay ? 16 : 8,
          onChanged: onTextChanged,
          decoration: InputDecoration(
            hintText: isEssay ? 'Write your essay answer' : 'Type your answer',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.brandSoft),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.brandSoft),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$wordCount word${wordCount == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (wordLimit != null) ...[
              const SizedBox(width: 8),
              Text(
                '· target $wordLimit',
                style: TextStyle(
                  color: wordCount > wordLimit
                      ? AppColors.danger
                      : AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        if (question.allowsImageUpload) ...[
          const SizedBox(height: 18),
          const Text(
            'Handwritten answer pages',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add photos of handwritten pages. AI OCR runs after you submit.',
            style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (images.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final image in images)
                  _ImageChip(
                    label: image.fileName,
                    pageNumber: image.pageNumber,
                    onRemove: onRemoveImage == null
                        ? null
                        : () => onRemoveImage!(image.mediaFileId),
                  ),
              ],
            ),
          if (images.isNotEmpty) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isUploading ? null : onAddImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(isUploading ? 'Uploading…' : 'Add page photos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brandSoft),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          if (isUploading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: uploadProgress <= 0 ? null : uploadProgress / 100,
                color: AppColors.brand,
                backgroundColor: AppColors.brandSoft,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Uploading… $uploadProgress%',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ],
    );
  }

  static int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
  }
}

class _ImageChip extends StatelessWidget {
  const _ImageChip({
    required this.label,
    this.pageNumber,
    this.onRemove,
  });

  final String label;
  final int? pageNumber;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final pageLabel = pageNumber != null ? 'Page $pageNumber' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(
            pageLabel,
            style: const TextStyle(color: AppColors.ink, fontSize: 12),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: AppColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
