import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/study_planner/domain/study_planner_models.dart';

void main() {
  test('StudyPlan.fromJson maps items to weekday sessions', () {
    final plan = StudyPlan.fromJson({
      'id': 'plan-1',
      'title': 'Weekly Focus',
      'plan_type': 'weekly',
      'items': [
        {
          'id': 'i1',
          'title': 'Revise Federalism',
          'topic_path': 'polity/federalism',
          'sort_order': 1,
          'estimated_minutes': 40,
          'metadata': {'time_start': '08:00', 'priority': 'high'},
        },
        {
          'id': 'i2',
          'title': 'MCQ Economy',
          'topic_path': 'economy/inflation',
          'sort_order': 2,
          'estimated_minutes': 30,
          'metadata': {'time_start': '14:30', 'kind': 'mcq'},
        },
      ],
    });

    expect(plan.title, 'Weekly Focus');
    expect(plan.sessions, hasLength(2));
    expect(plan.sessions.first.day, StudyDayName.monday);
    expect(plan.sessions.first.period, StudyPeriod.morning);
    expect(plan.sessions.first.timeLabel, contains('08:00'));
    expect(plan.sessions.last.kind, 'MCQ practice');
    expect(plan.sessionsForDay(StudyDayName.monday), hasLength(1));
    expect(plan.sessionsForDay(StudyDayName.tuesday), hasLength(1));
  });

  test('LearningGoal tracks open vs completed', () {
    const open = LearningGoal(
      id: 'g1',
      title: 'Study 60 minutes',
      targetValue: 60,
      currentValue: 20,
      unit: 'minutes',
      status: 'active',
    );
    expect(open.isOpen, isTrue);
    expect(open.progressLabel, '20 / 60 minutes');
    expect(open.copyWith(status: 'completed').isCompleted, isTrue);
  });

  test('todayDayName matches DateTime.weekday', () {
    final monday = DateTime(2026, 9, 14); // Monday
    expect(todayDayName(monday), StudyDayName.monday);
    final sunday = DateTime(2026, 9, 13);
    expect(todayDayName(sunday), StudyDayName.sunday);
  });
}
