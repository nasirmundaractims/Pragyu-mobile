import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/study_planner/data/study_planner_repository.dart';
import 'package:student_mobile/features/study_planner/domain/study_planner_models.dart';
import 'package:student_mobile/features/study_planner/presentation/screens/study_planner_screen.dart';

class _FakePlanner implements StudyPlannerGateway {
  _FakePlanner(this.snapshot);

  StudyPlannerSnapshot snapshot;
  int generateCalls = 0;
  int completeCalls = 0;

  @override
  Future<StudyPlannerSnapshot> loadPlanner() async => snapshot;

  @override
  Future<StudyPlan> generateWeeklyPlan({
    required String studentProfileId,
  }) async {
    generateCalls += 1;
    final today = todayDayName();
    final plan = StudyPlan(
      id: 'plan-new',
      title: 'Generated Week',
      planType: 'weekly',
      sessions: [
        StudySession(
          id: 's1',
          planId: 'plan-new',
          title: 'Polity focus',
          day: today,
          subject: 'Polity',
          estimatedMinutes: 45,
          timeStart: '09:00',
          timeEnd: '09:45',
          sortOrder: 1,
        ),
      ],
    );
    snapshot = snapshot.copyWith(
      plans: [plan, ...snapshot.plans],
      activePlanId: plan.id,
    );
    return plan;
  }

  @override
  Future<LearningGoal> completeGoal(String goalId) async {
    completeCalls += 1;
    final updated = snapshot.goals
        .firstWhere((g) => g.id == goalId)
        .copyWith(status: 'completed');
    snapshot = snapshot.copyWith(
      goals: [
        for (final goal in snapshot.goals)
          if (goal.id == goalId) updated else goal,
      ],
    );
    return updated;
  }
}

void main() {
  testWidgets('S-62 shows plan sessions and completes a goal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final monday = todayDayName();
    final fake = _FakePlanner(
      StudyPlannerSnapshot(
        studentProfileId: 'sp-1',
        activePlanId: 'plan-1',
        plans: [
          StudyPlan(
            id: 'plan-1',
            title: 'Exam Week',
            planType: 'weekly',
            sessions: [
              StudySession(
                id: 's1',
                planId: 'plan-1',
                title: 'Revise Federalism',
                day: monday,
                subject: 'Polity',
                estimatedMinutes: 40,
                timeStart: '08:00',
                timeEnd: '08:40',
                sortOrder: 1,
                priority: SessionPriority.high,
              ),
            ],
          ),
        ],
        goals: const [
          LearningGoal(
            id: 'g1',
            title: 'Study 60 minutes',
            targetValue: 60,
            currentValue: 15,
            unit: 'minutes',
            status: 'active',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudyPlannerScreen(plannerRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan your week with focus'), findsOneWidget);
    expect(find.text('Exam Week'), findsOneWidget);
    expect(find.text('Revise Federalism'), findsOneWidget);
    expect(find.text('Study 60 minutes'), findsOneWidget);

    await tester.ensureVisible(find.text('Complete'));
    await tester.tap(find.text('Complete'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fake.completeCalls, 1);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('S-62 empty plans can generate a weekly plan', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakePlanner(
      const StudyPlannerSnapshot(studentProfileId: 'sp-1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudyPlannerScreen(plannerRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No plans yet'), findsOneWidget);

    await tester.ensureVisible(find.text('Generate weekly plan'));
    await tester.tap(find.text('Generate weekly plan'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fake.generateCalls, 1);
    expect(find.text('Generated Week'), findsOneWidget);
    expect(find.text('Polity focus'), findsOneWidget);
  });
}
