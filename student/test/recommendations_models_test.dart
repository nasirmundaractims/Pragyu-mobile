import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/recommendations/domain/recommendations_models.dart';

void main() {
  test('RecommendationItem.fromJson maps payload and groups', () {
    final item = RecommendationItem.fromJson({
      'id': 'r1',
      'title': 'Fallback title',
      'recommendation_type': 'weak_topic_drill',
      'payload_json': {
        'what': 'Practice Federalism',
        'why': 'Mastery is low on this topic.',
        'when': 'Today',
        'duration_minutes': 25,
        'priority_label': 'high',
        'topic_path': 'polity/federalism',
        'category': 'weak_topic',
        'actions': [
          {'type': 'start_revision', 'label': 'Start revision'},
        ],
      },
    });

    expect(item.title, 'Practice Federalism');
    expect(item.estimatedMinutes, 25);
    expect(item.priority, RecommendationPriority.high);
    expect(item.groups, contains(RecommendationGroup.today));
    expect(item.groups, contains(RecommendationGroup.weakTopics));
    expect(item.groups, contains(RecommendationGroup.revision));
    expect(item.primaryAction.type, 'start_revision');
  });

  test('filtered hides dismissed and applies group + query', () {
    const snapshot = RecommendationsSnapshot(
      studentProfileId: 'sp-1',
      items: [
        RecommendationItem(
          id: 'a',
          title: 'Revise Polity',
          reason: 'Weak topic focus',
          priority: RecommendationPriority.high,
          groups: [RecommendationGroup.weakTopics, RecommendationGroup.today],
        ),
        RecommendationItem(
          id: 'b',
          title: 'MCQ Economy',
          reason: 'Drill objectives',
          priority: RecommendationPriority.medium,
          groups: [RecommendationGroup.mcq],
        ),
      ],
    );

    expect(
      snapshot.filtered(group: RecommendationGroup.weakTopics).map((e) => e.id),
      ['a'],
    );
    expect(
      snapshot.filtered(query: 'economy').map((e) => e.id),
      ['b'],
    );
    expect(
      snapshot.filtered(dismissed: {'a'}).map((e) => e.id),
      ['b'],
    );
  });
}
