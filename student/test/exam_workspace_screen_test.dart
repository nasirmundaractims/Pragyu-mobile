import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/exam_workspace/data/exam_workspace_repository.dart';
import 'package:student_mobile/features/exam_workspace/domain/exam_workspace_models.dart';
import 'package:student_mobile/features/exam_workspace/presentation/screens/exam_workspace_screen.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

class _FakeWorkspace implements ExamWorkspaceGateway {
  _FakeWorkspace(this.snapshot);

  final ExamWorkspaceSnapshot snapshot;

  @override
  Future<ExamWorkspaceSnapshot> loadWorkspace() async => snapshot;
}

ExamWorkspaceSnapshot _sample() {
  final exam = resolveExam(studentMetadata: {'exam_pattern': 'gpsc'});
  final display = buildExamDisplay(exam);
  return ExamWorkspaceSnapshot(
    studentProfileId: 'sp-1',
    exam: exam,
    display: display,
    readinessPct: 68,
    readinessFactors: const {
      'confidence': 0.7,
      'preparation_level': 'Intermediate',
    },
    weakTopics: const ['Federalism'],
    strongTopics: const ['Economy'],
    practiceSets: const [
      ExamPracticeSet(
        id: 'a1',
        title: 'GPSC Mock 1',
        type: 'exam',
        questionCount: 20,
        practiceKind: PracticeKind.mock,
      ),
    ],
    upcoming: const [
      ExamPracticeSet(
        id: 'a1',
        title: 'GPSC Mock 1',
        type: 'exam',
        questionCount: 20,
        practiceKind: PracticeKind.mock,
      ),
    ],
    recommendations: const [
      ExamRecommendationPreview(
        id: 'r1',
        title: 'Revise Federalism',
        reason: 'Low mastery signal',
      ),
    ],
    recentAttempts: [
      ExamRecentAttempt(
        submission: const SubmissionSummary(
          id: 'sub-1',
          assessmentId: 'a1',
          status: 'evaluated',
          percentage: 72,
        ),
        title: 'GPSC Mock 1',
      ),
    ],
    pendingCount: 1,
    evaluatedCount: 2,
    averageScore: 71,
    streak: 3,
    revisionDue: 2,
  );
}

void main() {
  testWidgets('S-66 shows hub, readiness, and practice sets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ExamWorkspaceScreen(workspaceRepository: _FakeWorkspace(_sample())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPSC Practice Hub'), findsOneWidget);
    expect(find.text('EXAM READINESS'), findsWidgets);
    expect(find.textContaining('Federalism'), findsWidgets);
    expect(find.text('GPSC Mock 1'), findsWidgets);
    expect(find.text('Practice hub'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('STUDY ROADMAP'), findsOneWidget);
  });

  testWidgets('S-66 empty practice still renders hub', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final exam = resolveExam();
    final fake = _FakeWorkspace(
      ExamWorkspaceSnapshot(
        studentProfileId: 'sp-1',
        exam: exam,
        display: buildExamDisplay(exam),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ExamWorkspaceScreen(workspaceRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('General Practice Hub'), findsOneWidget);
    expect(find.textContaining('No General-tagged assessments'), findsOneWidget);
    expect(find.text('Practice attempts will appear here.'), findsOneWidget);
  });
}
