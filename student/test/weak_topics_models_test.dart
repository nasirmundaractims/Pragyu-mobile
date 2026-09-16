import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/weak_topics/domain/weak_topics_models.dart';

void main() {
  test('WeakTopicItem.fromJson maps mastery and topic path', () {
    final item = WeakTopicItem.fromJson(
      {
        'id': 't1',
        'topic_path': 'polity/federalism',
        'mastery_score': 38,
        'difficulty': 'Hard',
        'attempts': 4,
        'average_score': 42,
      },
      status: TopicMasteryStatus.weak,
    );

    expect(item.name, 'polity/federalism');
    expect(item.mastery, 38);
    expect(item.difficulty, 'Hard');
    expect(item.attempts, 4);
    expect(item.whyShown, contains('42%'));
  });

  test('mergeWeakTopics upgrades weak to improving when mastery rises', () {
    final merged = mergeWeakTopics(
      weak: [
        const WeakTopicItem(
          id: 'w1',
          name: 'Federalism',
          mastery: 30,
          status: TopicMasteryStatus.weak,
        ),
      ],
      mastery: [
        const WeakTopicItem(
          id: 'm1',
          name: 'Federalism',
          mastery: 55,
          status: TopicMasteryStatus.improving,
        ),
      ],
      strong: const [],
    );

    expect(merged, hasLength(1));
    expect(merged.first.status, TopicMasteryStatus.improving);
    expect(merged.first.mastery, 55);
  });

  test('focusTopics excludes fully strong topics and sorts weak first', () {
    final snapshot = WeakTopicsSnapshot(
      studentProfileId: 'sp-1',
      topics: const [
        WeakTopicItem(
          id: 's1',
          name: 'Strong Topic',
          mastery: 90,
          status: TopicMasteryStatus.strong,
        ),
        WeakTopicItem(
          id: 'i1',
          name: 'Improving Topic',
          mastery: 58,
          status: TopicMasteryStatus.improving,
        ),
        WeakTopicItem(
          id: 'w1',
          name: 'Weak Topic',
          mastery: 28,
          status: TopicMasteryStatus.weak,
        ),
      ],
    );

    expect(snapshot.focusTopics.map((t) => t.name).toList(), [
      'Weak Topic',
      'Improving Topic',
    ]);
    expect(snapshot.needsWorkCount, 1);
    expect(snapshot.improvingCount, 1);
  });
}
