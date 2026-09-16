// S-50 Alerts — notification + engagement inbox models.

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
  });

  final String id;
  final AlertSource source;
  final String title;
  final String? body;
  final AlertCategory category;
  final bool isRead;
  final DateTime? createdAt;
  final String? eventType;

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
    );
  }

  factory AlertItem.fromNotificationJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id']?.toString() ?? '',
      source: AlertSource.notification,
      title: _titleFrom(json),
      body: _nullableTrim(
        json['body']?.toString() ?? json['message']?.toString(),
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
    );
  }

  factory AlertItem.fromInboxJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id']?.toString() ?? '',
      source: AlertSource.inbox,
      title: _titleFrom(json),
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
    );
  }

  static String _titleFrom(Map<String, dynamic> json) {
    return _nullableTrim(
          json['title']?.toString() ??
              json['subject']?.toString() ??
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
      value.contains('course')) {
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
