import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/exam_workspace/domain/exam_workspace_models.dart';

void main() {
  test('resolveExam prefers student profile metadata', () {
    final exam = resolveExam(
      studentMetadata: {'exam_pattern': 'gpsc'},
      organizationSettings: {'exam_pattern': 'upsc'},
      programExamPattern: 'ssc',
    );
    expect(exam.pattern, 'gpsc');
    expect(exam.label, 'GPSC');
    expect(exam.hubTitle, 'GPSC Practice Hub');
    expect(exam.source, ExamSource.studentProfile);
  });

  test('resolveExam falls back to assessment majority then general', () {
    final majority = resolveExam(
      assessmentPatterns: ['upsc', 'upsc', 'ssc'],
    );
    expect(majority.pattern, 'upsc');
    expect(majority.source, ExamSource.assessment);

    final fallback = resolveExam();
    expect(fallback.pattern, 'general');
    expect(fallback.source, ExamSource.fallback);
  });

  test('matchesExamPattern and classifyPractice', () {
    expect(
      matchesExamPattern({'title': 'GPSC Mock Paper'}, 'gpsc'),
      isTrue,
    );
    expect(
      classifyPractice({'title': 'Sectional Polity'}, 'quiz'),
      PracticeKind.section,
    );
    expect(readinessScore({'score': 0.72}), 72);
  });

  test('buildExamDisplay includes practice types and roadmap', () {
    final exam = resolveExam(studentMetadata: {'exam_pattern': 'upsc'});
    final display = buildExamDisplay(exam);
    expect(display.practiceTypes.length, 6);
    expect(display.roadmap.length, 5);
    expect(display.coachActions, isNotEmpty);
    expect(display.subtitle.contains('UPSC'), isTrue);
  });
}
