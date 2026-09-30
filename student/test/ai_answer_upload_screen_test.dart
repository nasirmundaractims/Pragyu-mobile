import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/tests/domain/ai_answer_upload_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/ai_answer_upload_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  AiAnswerUploadArgs args() => const AiAnswerUploadArgs(
        submissionId: 'sub-1',
        assessmentId: 'asm-1',
        questionIndex: 0,
        questionTotal: 1,
        finalizeOnSubmit: true,
        tags: ['GS Paper 3', 'Economy', 'Environment', 'Descriptive'],
        question: AssessmentQuestionPreview(
          id: 'q1',
          sortOrder: 1,
          maxMarks: 5,
          type: 'long_answer',
          content:
              'Discuss the role of sustainable development in achieving India’s long-term economic growth. Suggest key measures to balance development and environment.',
        ),
      );

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AiAnswerUploadScreen(args: args()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('upload screen matches reference structure without overflow',
      (tester) async {
    final overflows = <String>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed') || message.contains('OVERFLOWING')) {
        overflows.add(message);
      }
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    const sizes = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(375, 667),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
      Size(768, 1024),
    ];

    for (final size in sizes) {
      overflows.clear();
      await pumpAt(tester, size);

      expect(find.text('Upload Answer for Question'), findsOneWidget);
      expect(find.text('Your Answers. Smarter Feedback.'), findsOneWidget);
      expect(find.text('Question 1'), findsOneWidget);
      expect(find.text('5 Marks'), findsOneWidget);
      expect(find.text('Upload Your Answer Sheet'), findsOneWidget);
      expect(find.text('Open Camera'), findsOneWidget);
      expect(find.text('Select from Gallery'), findsOneWidget);
      expect(find.textContaining('Uploaded Pages'), findsOneWidget);
      expect(find.text('Tips for better evaluation'), findsOneWidget);
      expect(find.text('Submit for AI Evaluation'), findsOneWidget);
      expect(find.text('GS Paper 3'), findsOneWidget);

      expect(
        overflows,
        isEmpty,
        reason: 'RenderFlex overflow at ${size.width}x${size.height}',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
