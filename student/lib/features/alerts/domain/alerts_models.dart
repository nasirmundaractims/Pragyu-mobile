// S-50 Alerts — notification + engagement inbox models.
// S-51 deep-link fields extracted from payload / metadata.

enum AlertSource { notification, inbox }

enum AlertDayGroup { today, yesterday, earlier }

enum AlertCategory {
  assessment,
  evaluation,
  learning,
  messages,
  support,
  recommendations,
  system,
}

class AlertItem {
  const AlertItem({
    required this.id,
    required this.source,
    required this.title,
    this.body,
    this.category = AlertCategory.system,
    this.isRead = true,
    this.createdAt,
    this.eventType,
    this.actionUrl,
    this.payload = const {},
    this.assessmentId,
    this.submissionId,
    this.evaluationId,
    this.materialId,
    this.courseId,
    this.lessonId,
    this.resourceId,
    this.lectureId,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  final String id;
  final AlertSource source;
  final String title;
  final String? body;
  final AlertCategory category;
  final bool isRead;
  final DateTime? createdAt;
  final String? eventType;
  final String? actionUrl;
  final Map<String, dynamic> payload;
  final String? assessmentId;
  final String? submissionId;
  final String? evaluationId;
  final String? materialId;
  final String? courseId;
  final String? lessonId;
  final String? resourceId;
  final String? lectureId;
  final String? relatedEntityType;
  final String? relatedEntityId;

  String get categoryLabel => switch (category) {
        AlertCategory.assessment => 'Assessment',
        AlertCategory.evaluation => 'Evaluation',
        AlertCategory.learning => 'Learning',
        AlertCategory.messages => 'Messages',
        AlertCategory.support => 'Support',
        AlertCategory.recommendations => 'Recommendations',
        AlertCategory.system => 'System',
      };

  AlertDayGroup dayGroup({DateTime? now}) {
    final created = createdAt;
    if (created == null) return AlertDayGroup.earlier;
    final clock = now ?? DateTime.now();
    final todayStart = DateTime(clock.year, clock.month, clock.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    if (!created.isBefore(todayStart)) return AlertDayGroup.today;
    if (!created.isBefore(yesterdayStart)) return AlertDayGroup.yesterday;
    return AlertDayGroup.earlier;
  }

  AlertItem copyWith({bool? isRead}) {
    return AlertItem(
      id: id,
      source: source,
      title: title,
      body: body,
      category: category,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      eventType: eventType,
      actionUrl: actionUrl,
      payload: payload,
      assessmentId: assessmentId,
      submissionId: submissionId,
      evaluationId: evaluationId,
      materialId: materialId,
      courseId: courseId,
      lessonId: lessonId,
      resourceId: resourceId,
      lectureId: lectureId,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
    );
  }

  factory AlertItem.fromNotificationJson(Map<String, dynamic> json) {
    final payload = _asMap(json['payload']);
    final ids = _extractIds(json, payload);
    return AlertItem(
      id: json['id']?.toString() ?? '',
      source: AlertSource.notification,
      title: _titleFrom(json, payload),
      body: _nullableTrim(
        json['body']?.toString() ??
            json['message']?.toString() ??
            payload['body']?.toString() ??
            payload['message']?.toString(),
      ),
      category: categoryFromRaw(
        json['category']?.toString() ??
            json['event_type']?.toString() ??
            json['type']?.toString(),
      ),
      isRead: _isRead(json),
      createdAt: _parseDate(
        json['created_at']?.toString() ?? json['sent_at']?.toString(),
      ),
      eventType: _nullableTrim(json['event_type']?.toString()),
      actionUrl: ids.actionUrl,
      payload: payload,
      assessmentId: ids.assessmentId,
      submissionId: ids.submissionId,
      evaluationId: ids.evaluationId,
      materialId: ids.materialId,
      courseId: ids.courseId,
      lessonId: ids.lessonId,
      resourceId: ids.resourceId,
      lectureId: ids.lectureId,
      relatedEntityType: ids.relatedEntityType,
      relatedEntityId: ids.relatedEntityId,
    );
  }

  factory AlertItem.fromInboxJson(Map<String, dynamic> json) {
    final metadata = _asMap(json['metadata']);
    final ids = _extractIds(json, metadata);
    return AlertItem(
      id: json['id']?.toString() ?? '',
      source: AlertSource.inbox,
      title: _titleFrom(json, metadata),
      body: _nullableTrim(
        json['body']?.toString() ?? json['message']?.toString(),
      ),
      category: categoryFromRaw(
        json['item_type']?.toString() ??
            json['category']?.toString() ??
            json['type']?.toString(),
      ),
      isRead: _isRead(json),
      createdAt: _parseDate(json['created_at']?.toString()),
      eventType: _nullableTrim(json['item_type']?.toString()),
      actionUrl: ids.actionUrl,
      payload: metadata,
      assessmentId: ids.assessmentId ??
          _nullableTrim(
            json['reference_type']?.toString().toLowerCase() == 'assessment'
                ? json['reference_id']?.toString()
                : null,
          ),
      submissionId: ids.submissionId ??
          _nullableTrim(
            json['reference_type']?.toString().toLowerCase() == 'submission' ||
                    json['reference_type']?.toString().toLowerCase() ==
                        'answer_submission'
                ? json['reference_id']?.toString()
                : null,
          ),
      evaluationId: ids.evaluationId,
      materialId: ids.materialId,
      courseId: ids.courseId,
      lessonId: ids.lessonId,
      resourceId: ids.resourceId,
      lectureId: ids.lectureId,
      relatedEntityType: ids.relatedEntityType ??
          _nullableTrim(json['reference_type']?.toString()),
      relatedEntityId:
          ids.relatedEntityId ?? _nullableTrim(json['reference_id']?.toString()),
    );
  }

  static String _titleFrom(
    Map<String, dynamic> json, [
    Map<String, dynamic> payload = const {},
  ]) {
    return _nullableTrim(
          json['title']?.toString() ??
              json['subject']?.toString() ??
              payload['title']?.toString() ??
              payload['subject']?.toString() ??
              json['event_type']?.toString(),
        ) ??
        'Notification';
  }

  static bool _isRead(Map<String, dynamic> json) {
    if (json['read_at'] != null && json['read_at'].toString().isNotEmpty) {
      return true;
    }
    if (json['is_read'] == true || json['read'] == true) return true;
    if (json['is_read'] == false || json['read'] == false) return false;
    if (json['unread'] == true) return false;
    return true;
  }
}

class _DeepLinkIds {
  const _DeepLinkIds({
    this.actionUrl,
    this.assessmentId,
    this.submissionId,
    this.evaluationId,
    this.materialId,
    this.courseId,
    this.lessonId,
    this.resourceId,
    this.lectureId,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  final String? actionUrl;
  final String? assessmentId;
  final String? submissionId;
  final String? evaluationId;
  final String? materialId;
  final String? courseId;
  final String? lessonId;
  final String? resourceId;
  final String? lectureId;
  final String? relatedEntityType;
  final String? relatedEntityId;
}

_DeepLinkIds _extractIds(
  Map<String, dynamic> root,
  Map<String, dynamic> bag,
) {
  String? pick(List<String> keys) {
    for (final key in keys) {
      final fromBag = _nullableTrim(bag[key]?.toString());
      if (fromBag != null) return fromBag;
      final fromRoot = _nullableTrim(root[key]?.toString());
      if (fromRoot != null) return fromRoot;
    }
    return null;
  }

  return _DeepLinkIds(
    actionUrl: pick(const [
      'action_url',
      'actionUrl',
      'href',
      'url',
      'deep_link',
      'deepLink',
    ]),
    assessmentId: pick(const ['assessment_id', 'assessmentId']),
    submissionId: pick(const [
      'answer_submission_id',
      'submission_id',
      'answerSubmissionId',
      'submissionId',
    ]),
    evaluationId: pick(const ['evaluation_id', 'evaluationId']),
    materialId: pick(const ['material_id', 'materialId', 'study_material_id']),
    courseId: pick(const ['course_id', 'courseId']),
    lessonId: pick(const ['lesson_id', 'lessonId']),
    resourceId: pick(const ['resource_id', 'resourceId']),
    lectureId: pick(const ['lecture_id', 'lectureId']),
    relatedEntityType: pick(const [
      'related_entity_type',
      'relatedEntityType',
      'entity_type',
    ]),
    relatedEntityId: pick(const [
      'related_entity_id',
      'relatedEntityId',
      'entity_id',
    ]),
  );
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

class AlertsSnapshot {
  const AlertsSnapshot({
    this.items = const [],
    this.unreadCount = 0,
  });

  final List<AlertItem> items;
  final int unreadCount;

  int get pageUnreadCount => items.where((item) => !item.isRead).length;

  Map<AlertDayGroup, List<AlertItem>> grouped({DateTime? now}) {
    final buckets = <AlertDayGroup, List<AlertItem>>{
      AlertDayGroup.today: [],
      AlertDayGroup.yesterday: [],
      AlertDayGroup.earlier: [],
    };
    for (final item in items) {
      buckets[item.dayGroup(now: now)]!.add(item);
    }
    return buckets;
  }

  AlertsSnapshot markItemRead(String id) {
    final next = items
        .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList(growable: false);
    final unread = next.where((item) => !item.isRead).length;
    return AlertsSnapshot(items: next, unreadCount: unread);
  }

  AlertsSnapshot markAllRead() {
    final next =
        items.map((item) => item.copyWith(isRead: true)).toList(growable: false);
    return AlertsSnapshot(items: next, unreadCount: 0);
  }
}

AlertCategory categoryFromRaw(String? raw) {
  final value = (raw ?? 'system').toLowerCase();
  if (value.contains('assess')) return AlertCategory.assessment;
  if (value.contains('eval') ||
      value.contains('score') ||
      value.contains('feedback')) {
    return AlertCategory.evaluation;
  }
  if (value.contains('recommend')) return AlertCategory.recommendations;
  if (value.contains('learn') ||
      value.contains('coach') ||
      value.contains('plan') ||
      value.contains('lesson') ||
      value.contains('course') ||
      value.contains('lecture') ||
      value.contains('material')) {
    return AlertCategory.learning;
  }
  if (value.contains('announce') ||
      value.contains('message') ||
      value.contains('reply') ||
      value.contains('mention')) {
    return AlertCategory.messages;
  }
  if (value.contains('doubt') || value.contains('ticket')) {
    return AlertCategory.support;
  }
  return AlertCategory.system;
}

String dayGroupLabel(AlertDayGroup group) => switch (group) {
      AlertDayGroup.today => 'Today',
      AlertDayGroup.yesterday => 'Yesterday',
      AlertDayGroup.earlier => 'Earlier',
    };

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String? _nullableTrim(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
