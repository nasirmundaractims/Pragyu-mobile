import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/presentation/widgets/cbt_subjective_answer_panel.dart';

void main() {
  testWidgets('shows essay field, word count, and upload controls', (
    tester,
  ) async {
    const question = AssessmentQuestionPreview(
      id: 'aq1',
      questionId: 'q1',
      sortOrder: 1,
      content: 'Explain federalism in 250 words.',
      type: 'essay',
      wordLimit: 250,
      allowsImageUpload: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CbtSubjectiveAnswerPanel(
            question: question,
            kind: CbtQuestionKind.essay,
            answer: const StudentAnswerValue(
              text: 'Federalism divides powers.',
              images: [
                AnswerImageAttachment(
                  mediaFileId: 'm1',
                  fileName: 'page-1.jpg',
                  uploadedAt: '2026-09-16T00:00:00Z',
                  pageNumber: 1,
                ),
              ],
            ),
            onTextChanged: (_) {},
            onAddImages: () {},
            onRemoveImage: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Write your essay answer'), findsOneWidget);
    expect(find.textContaining('3 words'), findsOneWidget);
    expect(find.textContaining('target 250'), findsOneWidget);
    expect(find.text('Handwritten answer pages'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Add page photos'), findsOneWidget);
  });
}
