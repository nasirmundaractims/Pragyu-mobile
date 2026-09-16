/// S-63 Recommendations models.
library;

enum RecommendationPriority { critical, high, medium, low }

enum RecommendationGroup {
  today,
  thisWeek,
  weakTopics,
  revision,
  answerWriting,
  mcq,
}

extension RecommendationGroupX on RecommendationGroup {
  String get label {
    switch (this) {
      case RecommendationGroup.today:
        return 'Today';
      case RecommendationGroup.thisWeek:
        return 'This week';
      case RecommendationGroup.weakTopics:
        return 'Weak topics';
      case RecommendationGroup.revision:
        return 'Revision';
      case RecommendationGroup.answerWriting:
        return 'Answer writing';
      case RecommendationGroup.mcq:
        return 'MCQ';
    }
  }
}

class RecommendationAction {
  const RecommendationAction({
    required this.type,
    required this.label,
    this.topicPath,
    this.minutes,
  });

  final String type;
  final String label;
  final String? topicPath;
  final int? minutes;

  factory RecommendationAction.fromJson(
    Map<String, dynamic> json, {
    String? fallbackTopic,
    int fallbackMinutes = 30,
  }) {
    final type = (json['type'] ?? '').toString().trim();
    return RecommendationAction(
      type: type.isEmpty ? 'ask_ai_coach' : type,
      label: (json['label'] ?? _defaultActionLabel(type)).toString(),
      topicPath: (json['topic_path'] ?? fallbackTopic)?.toString(),
      minutes: _int(json['minutes']) ?? fallbackMinutes,
    );
  }
}

class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.title,
    required this.reason,
    this.estimatedMinutes = 30,
    this.whenLabel = 'This week',
    this.priority = RecommendationPriority.medium,
    this.confidence,
    this.category = 'practice',
    this.topicPath,
    this.recommendationType = '',
    this.difficulty = 'Medium',
    this.actions = const [],
    this.groups = const [],
    this.expectedBenefit,
  });

  final String id;
  final String title;
  final String reason;
  final int estimatedMinutes;
  final String whenLabel;
  final RecommendationPriority priority;
  final double? confidence;
  final String category;
  final String? topicPath;
  final String recommendationType;
  final String difficulty;
  final List<RecommendationAction> actions;
  final List<RecommendationGroup> groups;
  final String? expectedBenefit;

  String get priorityLabel {
    switch (priority) {
      case RecommendationPriority.critical:
        return 'Critical';
      case RecommendationPriority.high:
        return 'High';
      case RecommendationPriority.medium:
        return 'Medium';
      case RecommendationPriority.low:
        return 'Low';
    }
  }

  int get priorityWeight {
    switch (priority) {
      case RecommendationPriority.critical:
        return 4;
      case RecommendationPriority.high:
        return 3;
      case RecommendationPriority.medium:
        return 2;
      case RecommendationPriority.low:
        return 1;
    }
  }

  bool get isHighPriority =>
      priority == RecommendationPriority.critical ||
      priority == RecommendationPriority.high;

  RecommendationAction get primaryAction => actions.isNotEmpty
      ? actions.first
      : const RecommendationAction(type: 'ask_ai_coach', label: 'Ask Mentor');

  factory RecommendationItem.fromJson(
    Map<String, dynamic> json, {
    int index = 0,
  }) {
    final payload = _asMap(json['payload_json'] ?? json['payload'] ?? json['metadata_json'] ?? json['metadata']);
    final id = (json['id'] ?? 'rec-$index').toString();
    final title = _firstNonEmpty([
      payload['what'],
      json['title'],
      json['topic_path'],
      payload['topic_path'],
      'Recommended action',
    ]);
    final why = _firstNonEmpty([
      payload['why'],
      json['reason'],
      json['description'],
      payload['content'],
      'AI prioritized this for your goals',
    ]);
    final minutes = _int(payload['duration_minutes']) ??
        _int(json['estimated_minutes']) ??
        30;
    final topicPath = _nullableString(payload['topic_path'] ?? json['topic_path']);
    final category = (payload['category'] ?? json['category'] ?? 'practice')
        .toString();
    final recommendationType =
        (json['recommendation_type'] ?? category).toString();
    final when = _firstNonEmpty([payload['when'], 'This week']);
    final actionsRaw = payload['actions'];
    final actions = <RecommendationAction>[];
    if (actionsRaw is List) {
      for (final row in actionsRaw) {
        if (row is Map) {
          actions.add(
            RecommendationAction.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
              fallbackTopic: topicPath,
              fallbackMinutes: minutes,
            ),
          );
        }
      }
    }
    if (actions.isEmpty) {
      actions.add(
        RecommendationAction(
          type: 'ask_ai_coach',
          label: 'Ask Mentor',
          topicPath: topicPath,
          minutes: minutes,
        ),
      );
    }

    final item = RecommendationItem(
      id: id,
      title: title,
      reason: why,
      estimatedMinutes: minutes,
      whenLabel: when,
      priority: _priority(payload['priority_label'] ?? json['priority'] ?? index),
      confidence: _confidence(payload['confidence'] ?? json['confidence']),
      category: category,
      topicPath: topicPath,
      recommendationType: recommendationType,
      difficulty: (json['difficulty'] ?? payload['difficulty'] ?? 'Medium')
          .toString(),
      actions: actions,
      expectedBenefit: _nullableString(payload['expected_benefit']),
      groups: resolveRecommendationGroups(
        when: when,
        category: category,
        recommendationType: recommendationType,
        actions: actions,
        topicPath: topicPath,
      ),
    );
    return item;
  }
}

class RecommendationsSnapshot {
  const RecommendationsSnapshot({
    required this.studentProfileId,
    this.items = const [],
    this.weakTopicCount = 0,
  });

  final String studentProfileId;
  final List<RecommendationItem> items;
  final int weakTopicCount;

  int get highPriorityCount =>
      items.where((item) => item.isHighPriority).length;

  int get todayCount => items
      .where((item) => item.groups.contains(RecommendationGroup.today))
      .length;

  List<RecommendationItem> filtered({
    RecommendationGroup? group,
    String query = '',
    Set<String> dismissed = const {},
  }) {
    final q = query.trim().toLowerCase();
    final list = items.where((item) {
      if (dismissed.contains(item.id)) return false;
      if (group != null && !item.groups.contains(group)) return false;
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.reason.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final byPriority = b.priorityWeight.compareTo(a.priorityWeight);
        if (byPriority != 0) return byPriority;
        return (b.confidence ?? 0).compareTo(a.confidence ?? 0);
      });
    return list;
  }

  RecommendationsSnapshot copyWith({
    List<RecommendationItem>? items,
    int? weakTopicCount,
  }) {
    return RecommendationsSnapshot(
      studentProfileId: studentProfileId,
      items: items ?? this.items,
      weakTopicCount: weakTopicCount ?? this.weakTopicCount,
    );
  }
}

List<RecommendationGroup> resolveRecommendationGroups({
  required String when,
  required String category,
  required String recommendationType,
  required List<RecommendationAction> actions,
  String? topicPath,
}) {
  final groups = <RecommendationGroup>{};
  final whenLower = when.toLowerCase();
  final categoryLower = category.toLowerCase();
  final typeLower = recommendationType.toLowerCase();
  final actionTypes = actions.map((a) => a.type).toSet();

  if (_matchesWhen(whenLower, const [
    'today',
    'tonight',
    'this morning',
    'this evening',
    'now',
  ])) {
    groups.add(RecommendationGroup.today);
  }
  if (_matchesWhen(whenLower, const [
        'week',
        'tomorrow',
        'weekend',
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ]) ||
      (!groups.contains(RecommendationGroup.today) && whenLower.isNotEmpty)) {
    groups.add(RecommendationGroup.thisWeek);
  }

  if (typeLower.contains('weak') ||
      typeLower == 'weak_topic_drill' ||
      typeLower == 'weak_topic' ||
      categoryLower == 'weak_topic') {
    groups.add(RecommendationGroup.weakTopics);
  }

  if (categoryLower == 'revision' ||
      typeLower == 'revision' ||
      actionTypes.contains('start_revision')) {
    groups.add(RecommendationGroup.revision);
  }

  if (categoryLower == 'answer_writing' ||
      actionTypes.contains('write_answer')) {
    groups.add(RecommendationGroup.answerWriting);
  }

  if (categoryLower == 'mcq' || actionTypes.contains('start_mcq')) {
    groups.add(RecommendationGroup.mcq);
  }

  if (groups.isEmpty) {
    groups.add(RecommendationGroup.thisWeek);
  }
  return groups.toList(growable: false);
}

bool _matchesWhen(String hay, List<String> needles) =>
    needles.any(hay.contains);

String _defaultActionLabel(String type) {
  switch (type) {
    case 'start_revision':
      return 'Start revision';
    case 'open_topic':
      return 'Open topic';
    case 'write_answer':
      return 'Write answer';
    case 'start_mcq':
      return 'Start MCQ';
    case 'ask_ai_coach':
      return 'Ask Mentor';
    case 'add_to_planner':
    case 'generate_weekly_plan':
      return 'Open planner';
    default:
      return 'Start';
  }
}

RecommendationPriority _priority(Object? raw) {
  if (raw is int) {
    if (raw < 2) return RecommendationPriority.high;
    if (raw < 4) return RecommendationPriority.medium;
    return RecommendationPriority.low;
  }
  final text = (raw ?? 'medium').toString().toLowerCase();
  switch (text) {
    case 'critical':
      return RecommendationPriority.critical;
    case 'high':
      return RecommendationPriority.high;
    case 'low':
      return RecommendationPriority.low;
    case 'medium':
      return RecommendationPriority.medium;
  }
  final numeric = double.tryParse(text);
  if (numeric == null) return RecommendationPriority.medium;
  if (numeric >= 90) return RecommendationPriority.critical;
  if (numeric >= 75) return RecommendationPriority.high;
  if (numeric >= 50) return RecommendationPriority.medium;
  return RecommendationPriority.low;
}

double? _confidence(Object? raw) {
  final n = _double(raw);
  if (n == null) return null;
  if (n > 1) return (n / 100).clamp(0, 1);
  return n.clamp(0, 1);
}

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String? _nullableString(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

int? _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

double? _double(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}
