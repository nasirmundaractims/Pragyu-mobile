import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/analytics/data/analytics_repository.dart';
import 'package:student_mobile/features/analytics/domain/analytics_models.dart';
import 'package:student_mobile/features/analytics/presentation/screens/performance_analytics_screen.dart';

class _FakeAnalytics implements AnalyticsGateway {
  _FakeAnalytics(this.snapshot);

  final PerformanceSnapshot snapshot;

  @override
  Future<PerformanceSnapshot> loadPerformance() async => snapshot;
}

void main() {
  testWidgets('S-65 shows KPIs, insights, and subjects', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeAnalytics(
      const PerformanceSnapshot(
        studentProfileId: 'sp-1',
        overallAverage: 74,
        learningProgress: 58,
        streak: 4,
        completedAssessments: 6,
        practiceSessions: 3,
        improvement: 5,
        periodType: 'weekly',
        weakTopics: [
          PerformanceTopic(id: 'w1', name: 'Federalism', mastery: 32),
        ],
        subjects: [
          SubjectPerformance(
            subjectId: 'a1',
            title: 'Polity Weekly',
            count: 3,
            average: 68,
            improvement: 8,
          ),
        ],
        scoreTrend: [
          ScoreTrendPoint(
            submissionId: 's1',
            assessmentId: 'a1',
            title: 'Polity Weekly',
            percentage: 68,
            at: null,
          ),
          ScoreTrendPoint(
            submissionId: 's2',
            assessmentId: 'a1',
            title: 'Polity Weekly',
            percentage: 76,
            at: null,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PerformanceAnalyticsScreen(analyticsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Overall score'), findsOneWidget);
    expect(find.text('74%'), findsWidgets);
    expect(find.textContaining('Federalism'), findsWidgets);
    expect(find.text('Polity Weekly'), findsWidgets);
    expect(find.text('AI insights'), findsOneWidget);
    expect(find.text('Subject analysis'), findsOneWidget);
  });

  testWidgets('S-65 empty state still shows starter journey', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeAnalytics(
      const PerformanceSnapshot(studentProfileId: 'sp-1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PerformanceAnalyticsScreen(analyticsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Starter'), findsOneWidget);
    expect(find.textContaining('Complete a few assessments'), findsOneWidget);
    expect(find.text('No subject scores yet'), findsOneWidget);
  });
}
