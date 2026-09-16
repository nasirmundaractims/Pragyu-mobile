/// S-62 Study planner models.
library;

enum StudyDayName {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

enum StudyPeriod { morning, afternoon, evening, night }

enum SessionPriority { high, medium, low }

const weekDayOrder = [
  StudyDayName.monday,
  StudyDayName.tuesday,
  StudyDayName.wednesday,
  StudyDayName.thursday,
  StudyDayName.friday,
  StudyDayName.saturday,
  StudyDayName.sunday,
];

extension StudyDayNameX on StudyDayName {
  String get label {
    switch (this) {
      case StudyDayName.monday:
        return 'Monday';
      case StudyDayName.tuesday:
        return 'Tuesday';
      case StudyDayName.wednesday:
        return 'Wednesday';
      case StudyDayName.thursday:
        return 'Thursday';
      case StudyDayName.friday:
        return 'Friday';
      case StudyDayName.saturday:
        return 'Saturday';
      case StudyDayName.sunday:
        return 'Sunday';
    }
  }

  String get shortLabel => label.substring(0, 3);
}

StudyDayName todayDayName([DateTime? now]) {
  final day = (now ?? DateTime.now()).weekday; // Mon=1 … Sun=7
  return weekDayOrder[day - 1];
}

StudyDayName dayFromSortOrder(int sortOrder) {
  final zeroBased = sortOrder <= 0 ? 0 : sortOrder - 1;
  return weekDayOrder[zeroBased % weekDayOrder.length];
}

StudyPeriod periodOf({String? timeStart, int sortOrder = 0}) {
  if (timeStart != null && timeStart.isNotEmpty) {
    final hour = int.tryParse(timeStart.split(':').first) ?? 12;
    if (hour >= 5 && hour < 12) return StudyPeriod.morning;
    if (hour >= 12 && hour < 17) return StudyPeriod.afternoon;
    if (hour >= 17 && hour < 21) return StudyPeriod.evening;
    return StudyPeriod.night;
  }
  return StudyPeriod.values[sortOrder % StudyPeriod.values.length];
}

class StudySession {
  const StudySession({
    required this.id,
    required this.planId,
    required this.title,
    required this.day,
    this.subject = 'General',
    this.topic = '',
    this.description,
    this.estimatedMinutes = 45,
    this.priority = SessionPriority.medium,
    this.kind = 'Study session',
    this.timeStart,
    this.timeEnd,
    this.sortOrder = 1,
    this.status = 'pending',
  });

  final String id;
  final String planId;
  final String title;
  final StudyDayName day;
  final String subject;
  final String topic;
  final String? description;
  final int estimatedMinutes;
  final SessionPriority priority;
  final String kind;
  final String? timeStart;
  final String? timeEnd;
  final int sortOrder;
  final String status;

  StudyPeriod get period =>
      periodOf(timeStart: timeStart, sortOrder: sortOrder);

  String get timeLabel {
    if (timeStart == null || timeStart!.isEmpty) return '$estimatedMinutes min';
    if (timeEnd == null || timeEnd!.isEmpty) {
      return '$timeStart · $estimatedMinutes min';
    }
    return '$timeStart – $timeEnd';
  }

  factory StudySession.fromJson(
    Map<String, dynamic> json, {
    required String planId,
    int index = 0,
  }) {
    final metadata = _asMap(json['metadata_json'] ?? json['metadata']);
    final topic = (json['topic_path'] ?? metadata['topic_path'] ?? 'general')
        .toString();
    final title = (json['title'] ?? 'Study session').toString();
    final sortOrder = _int(json['sort_order']) ?? index + 1;
    final minutes = _int(json['estimated_minutes']) ??
        _int(metadata['estimated_minutes']) ??
        45;
    final timeStart = _parseTime(
      metadata['time_start'] ?? metadata['start_time'] ?? metadata['time'],
    );
    final timeEnd = timeStart == null
        ? null
        : _parseTime(metadata['time_end'] ?? metadata['end_time']) ??
            _addMinutes(timeStart, minutes);

    return StudySession(
      id: json['id']?.toString() ?? '$planId-$index',
      planId: planId,
      title: title,
      day: dayFromSortOrder(sortOrder),
      subject: _topicToSubject(topic),
      topic: topic,
      description: json['description']?.toString(),
      estimatedMinutes: minutes,
      priority: _priority(metadata['priority'], index),
      kind: _kindLabel(title, metadata),
      timeStart: timeStart,
      timeEnd: timeEnd,
      sortOrder: sortOrder,
      status: (json['status'] ?? 'pending').toString(),
    );
  }
}

class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.title,
    this.description,
    this.planType = 'weekly',
    this.createdAt,
    this.sessions = const [],
    this.priorityTopics = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String planType;
  final DateTime? createdAt;
  final List<StudySession> sessions;
  final List<String> priorityTopics;

  int get totalMinutes =>
      sessions.fold(0, (sum, s) => sum + s.estimatedMinutes);

  List<StudySession> sessionsForDay(StudyDayName day) {
    final list = sessions.where((s) => s.day == day).toList()
      ..sort((a, b) {
        final ta = a.timeStart ?? '';
        final tb = b.timeStart ?? '';
        final byTime = ta.compareTo(tb);
        if (byTime != 0) return byTime;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return list;
  }

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final settings = _asMap(json['settings_json'] ?? json['settings'] ?? json['metadata']);
    final itemsRaw = json['items'];
    final sessions = <StudySession>[];
    if (itemsRaw is List) {
      for (var i = 0; i < itemsRaw.length; i++) {
        final row = itemsRaw[i];
        if (row is Map) {
          sessions.add(
            StudySession.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
              planId: id,
              index: i,
            ),
          );
        }
      }
    }

    return StudyPlan(
      id: id,
      title: (json['title'] ?? json['plan_type'] ?? 'Study plan').toString(),
      description: json['description']?.toString(),
      planType: (json['plan_type'] ?? 'weekly').toString(),
      createdAt: _parseDate(json['created_at']?.toString()),
      sessions: sessions,
      priorityTopics: _stringList(settings['priority_topics']),
    );
  }
}

class LearningGoal {
  const LearningGoal({
    required this.id,
    required this.title,
    this.description,
    this.goalType = 'study_time',
    this.targetValue = 0,
    this.currentValue = 0,
    this.unit = 'minutes',
    this.status = 'active',
  });

  final String id;
  final String title;
  final String? description;
  final String goalType;
  final double targetValue;
  final double currentValue;
  final String unit;
  final String status;

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isOpen => !isCompleted;

  String get progressLabel {
    final current = currentValue == currentValue.roundToDouble()
        ? currentValue.toInt().toString()
        : currentValue.toStringAsFixed(1);
    final target = targetValue == targetValue.roundToDouble()
        ? targetValue.toInt().toString()
        : targetValue.toStringAsFixed(1);
    return '$current / $target $unit';
  }

  factory LearningGoal.fromJson(Map<String, dynamic> json) {
    return LearningGoal(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? 'Goal').toString(),
      description: json['description']?.toString(),
      goalType: (json['goal_type'] ?? 'study_time').toString(),
      targetValue: _double(json['target_value']) ?? 0,
      currentValue: _double(json['current_value']) ?? 0,
      unit: (json['unit'] ?? 'minutes').toString(),
      status: (json['status'] ?? 'active').toString(),
    );
  }

  LearningGoal copyWith({String? status}) {
    return LearningGoal(
      id: id,
      title: title,
      description: description,
      goalType: goalType,
      targetValue: targetValue,
      currentValue: currentValue,
      unit: unit,
      status: status ?? this.status,
    );
  }
}

class StudyPlannerSnapshot {
  const StudyPlannerSnapshot({
    required this.studentProfileId,
    this.plans = const [],
    this.goals = const [],
    this.activePlanId,
  });

  final String studentProfileId;
  final List<StudyPlan> plans;
  final List<LearningGoal> goals;
  final String? activePlanId;

  StudyPlan? get activePlan {
    if (plans.isEmpty) return null;
    if (activePlanId != null) {
      for (final plan in plans) {
        if (plan.id == activePlanId) return plan;
      }
    }
    return plans.first;
  }

  List<LearningGoal> get openGoals =>
      goals.where((g) => g.isOpen).toList(growable: false);

  StudyPlannerSnapshot copyWith({
    List<StudyPlan>? plans,
    List<LearningGoal>? goals,
    String? activePlanId,
  }) {
    return StudyPlannerSnapshot(
      studentProfileId: studentProfileId,
      plans: plans ?? this.plans,
      goals: goals ?? this.goals,
      activePlanId: activePlanId ?? this.activePlanId,
    );
  }
}

String _topicToSubject(String topicPath) {
  final parts = topicPath.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'General';
  final raw = parts.first.replaceAll(RegExp(r'[-_]'), ' ');
  return raw
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

SessionPriority _priority(Object? raw, int index) {
  switch ((raw ?? '').toString().toLowerCase()) {
    case 'high':
      return SessionPriority.high;
    case 'low':
      return SessionPriority.low;
    case 'medium':
      return SessionPriority.medium;
    default:
      if (index < 3) return SessionPriority.high;
      if (index < 6) return SessionPriority.medium;
      return SessionPriority.low;
  }
}

String _kindLabel(String title, Map<String, dynamic> metadata) {
  final raw =
      (metadata['kind'] ?? metadata['session_type'] ?? metadata['type'] ?? '')
          .toString()
          .toLowerCase();
  switch (raw) {
    case 'revision':
      return 'Revision';
    case 'new_learning':
      return 'New learning';
    case 'answer_writing':
      return 'Answer writing';
    case 'mcq':
      return 'MCQ practice';
    case 'current_affairs':
      return 'Current affairs';
    case 'custom':
      return 'Study session';
  }
  final hay = title.toLowerCase();
  if (hay.contains('revision') || hay.contains('revise')) return 'Revision';
  if (hay.contains('mcq') || hay.contains('quiz')) return 'MCQ practice';
  if (hay.contains('answer')) return 'Answer writing';
  return 'Study session';
}

String? _parseTime(Object? value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return null;
  final hours = int.parse(match.group(1)!);
  final mins = int.parse(match.group(2)!);
  if (hours > 23 || mins > 59) return null;
  return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
}

String _addMinutes(String start, int minutes) {
  final parts = start.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final total = h * 60 + m + minutes;
  final wrapped = ((total % (24 * 60)) + 24 * 60) % (24 * 60);
  final hh = wrapped ~/ 60;
  final mm = wrapped % 60;
  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
