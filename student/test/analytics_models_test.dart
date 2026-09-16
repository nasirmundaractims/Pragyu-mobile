import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/analytics/domain/analytics_models.dart';

void main() {
  test('computeSubmissionStreak counts consecutive days', () {
    final now = DateTime(2026, 9, 16);
    final streak = computeSubmissionStreak(
      [
        DateTime(2026, 9, 16, 10),
        DateTime(2026, 9, 15, 9),
        DateTime(2026, 9, 14, 8),
        DateTime(2026, 9, 12, 8),
      ],
      now: now,
    );
    expect(streak, 3);
  });

  test('PerformanceSnapshot builds insights from weak topics', () {
    const snapshot = PerformanceSnapshot(
      studentProfileId: 'sp-1',
      overallAverage: 62,
      improvement: -4,
      weakTopics: [
        PerformanceTopic(id: 'w1', name: 'Federalism', mastery: 30),
      ],
      strongTopics: [
        PerformanceTopic(id: 's1', name: 'Economy', mastery: 82),
      ],
    );

    expect(snapshot.levelLabel, 'Explorer');
    expect(snapshot.insights, isNotEmpty);
    expect(
      snapshot.insights.any((i) => i.title.contains('Federalism')),
      isTrue,
    );
    expect(
      snapshot.insights.any((i) => i.title.contains('dipped')),
      isTrue,
    );
  });
}
