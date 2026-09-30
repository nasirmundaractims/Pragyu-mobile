import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';

/// Route args for the AI answer sheet upload screen (short/long answer photos).
class AiAnswerUploadArgs {
  const AiAnswerUploadArgs({
    required this.submissionId,
    required this.assessmentId,
    required this.question,
    required this.questionIndex,
    this.questionTotal = 1,
    this.assessmentTitle,
    this.existingImages = const [],
    this.existingText,
    this.finalizeOnSubmit = false,
    this.tags = const [],
  });

  final String submissionId;
  final String assessmentId;
  final AssessmentQuestionPreview question;
  final int questionIndex;
  final int questionTotal;
  final String? assessmentTitle;
  final List<AnswerImageAttachment> existingImages;
  final String? existingText;
  final bool finalizeOnSubmit;
  final List<String> tags;

  factory AiAnswerUploadArgs.fromObject(Object? raw) {
    if (raw is AiAnswerUploadArgs) return raw;
    return AiAnswerUploadArgs(
      submissionId: '',
      assessmentId: '',
      question: const AssessmentQuestionPreview(
        id: '',
        sortOrder: 0,
      ),
      questionIndex: 0,
    );
  }
}

/// Result returned to the attempt player after upload / submit.
class AiAnswerUploadResult {
  const AiAnswerUploadResult({
    required this.images,
    this.text,
    this.finalized = false,
    this.submissionStatus,
  });

  final List<AnswerImageAttachment> images;
  final String? text;
  final bool finalized;
  final String? submissionStatus;
}
