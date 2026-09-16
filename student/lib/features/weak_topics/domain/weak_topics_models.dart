/// S-61 Weak topics / improvement hub models.
library;

enum TopicMasteryStatus { weak, improving, needsRevision, strong }

class WeakTopicItem {
  const WeakTopicItem({
    required this.id,
    required this.name,
    required this.mastery,
    this.status = TopicMasteryStatus.weak,
    this.difficulty = 'Medium',
    this.attempts,
    this.averageScore,
    this.lastPracticedAt,
    this.subjectId,
    this.topicPath,
  });

  final String id;
  final String name;
  final int mastery;
  final TopicMasteryStatus status;
  final String difficulty;
  final int? attempts;
  final double? averageScore;
  final DateTime? lastPracticedAt;
  final String? subjectId;
  final String? topicPath;

  String get whyShown {
    switch (status) {
      case TopicMasteryStatus.improving:
        return 'You were struggling here, but recent practice shows clear progress.';
      case TopicMasteryStatus.needsRevision:
        return 'Due for revision based on your spaced-repetition schedule.';
      case TopicMasteryStatus.strong:
        return 'Turning around — keep reinforcing so it stays strong.';
      case TopicMasteryStatus.weak:
        if (averageScore != null && averageScore! < 50) {
          return 'Low average score (${averageScore!.round()}%) on recent attempts.';
        }
        if (mastery < 45) {
          return 'Mastery is still low ($mastery%) — keep this on your focus list.';
        }
        return 'Marked as a focus area from your evaluation signals.';
    }
  }

  String get statusLabel {
    switch (status) {
      case TopicMasteryStatus.improving:
        return 'Improving';
      case TopicMasteryStatus.strong:
        return 'Improved';
      case TopicMasteryStatus.needsRevision:
        return 'Needs revision';
      case TopicMasteryStatus.weak:
        return 'Needs work';
    }
  }

  WeakTopicItem copyWith({
    int? mastery,
    TopicMasteryStatus? status,
    String? difficulty,
    int? attempts,
    double? averageScore,
    DateTime? lastPracticedAt,
  }) {
    return WeakTopicItem(
      id: id,
      name: name,
      mastery: mastery ?? this.mastery,
      status: status ?? this.status,
      difficulty: difficulty ?? this.difficulty,
      attempts: attempts ?? this.attempts,
      averageScore: averageScore ?? this.averageScore,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      subjectId: subjectId,
      topicPath: topicPath,
    );
  }

  factory WeakTopicItem.fromJson(
    Map<String, dynamic> json, {
    required TopicMasteryStatus status,
    int index = 0,
  }) {
    final name = _topicName(json);
    final mastery = _pct(
      json['mastery_score'] ??
          json['mastery'] ??
          json['mastery_percent'] ??
          json['score'] ??
          json['level'] ??
          json['confidence'],
    );
    final attemptsRaw = json['attempts'] ?? json['attempt_count'];
    final avgRaw = json['average_score'] ?? json['avg_score'] ?? json['score'];
    return WeakTopicItem(
      id: json['id']?.toString() ?? '$status-$index-$name',
      name: name,
      mastery: mastery,
      status: status,
      difficulty: (json['difficulty'] ?? json['level_label'] ?? json['level'] ?? 'Medium')
          .toString(),
      attempts: attemptsRaw is num
          ? attemptsRaw.round()
          : int.tryParse(attemptsRaw?.toString() ?? ''),
      averageScore: avgRaw is num
          ? avgRaw.toDouble()
          : double.tryParse(avgRaw?.toString() ?? ''),
      lastPracticedAt: _parseDate(
        (json['last_practiced_at'] ?? json['updated_at'] ?? json['last_detected_at'])
            ?.toString(),
      ),
      subjectId: json['subject_id']?.toString(),
      topicPath: json['topic_path']?.toString() ?? name,
    );
  }
}

class WeakTopicsSnapshot {
  const WeakTopicsSnapshot({
    required this.studentProfileId,
    this.topics = const [],
  });

  final String studentProfileId;
  final List<WeakTopicItem> topics;

  int get needsWorkCount =>
      topics.where((t) => t.status == TopicMasteryStatus.weak).length;

  int get improvingCount =>
      topics.where((t) => t.status == TopicMasteryStatus.improving).length;

  int get turningAroundCount => topics
      .where(
        (t) =>
            t.status == TopicMasteryStatus.strong ||
            (t.status == TopicMasteryStatus.improving && t.mastery >= 60),
      )
      .length;

  /// Focus list for S-61: exclude fully strong topics.
  List<WeakTopicItem> get focusTopics {
    final focus = topics.where((t) {
      if (t.status == TopicMasteryStatus.strong && t.mastery >= 75) {
        return false;
      }
      if (t.status == TopicMasteryStatus.weak ||
          t.status == TopicMasteryStatus.improving ||
          t.status == TopicMasteryStatus.needsRevision) {
        return true;
      }
      return t.mastery < 60;
    }).toList();

    int rank(TopicMasteryStatus s) {
      switch (s) {
        case TopicMasteryStatus.weak:
          return 0;
        case TopicMasteryStatus.needsRevision:
          return 1;
        case TopicMasteryStatus.improving:
          return 2;
        case TopicMasteryStatus.strong:
          return 3;
      }
    }

    focus.sort((a, b) {
      final byStatus = rank(a.status).compareTo(rank(b.status));
      if (byStatus != 0) return byStatus;
      return a.mastery.compareTo(b.mastery);
    });
    return focus;
  }
}

TopicMasteryStatus statusFromMastery(int mastery) {
  if (mastery < 45) return TopicMasteryStatus.weak;
  if (mastery >= 75) return TopicMasteryStatus.strong;
  return TopicMasteryStatus.improving;
}

List<WeakTopicItem> mergeWeakTopics({
  required List<WeakTopicItem> weak,
  required List<WeakTopicItem> mastery,
  required List<WeakTopicItem> strong,
}) {
  final byName = <String, WeakTopicItem>{};

  for (final topic in mastery) {
    byName[topic.name.toLowerCase()] = topic;
  }
  for (final topic in weak) {
    final key = topic.name.toLowerCase();
    final existing = byName[key];
    if (existing == null) {
      byName[key] = topic.copyWith(status: TopicMasteryStatus.weak);
      continue;
    }
    // Prefer mastery-derived improving/strong over forever-weak.
    if (existing.mastery >= 45) {
      byName[key] = existing.copyWith(
        status: existing.mastery >= 75
            ? TopicMasteryStatus.strong
            : TopicMasteryStatus.improving,
      );
    } else {
      byName[key] = existing.copyWith(status: TopicMasteryStatus.weak);
    }
  }
  for (final topic in strong) {
    final key = topic.name.toLowerCase();
    final existing = byName[key];
    if (existing == null) {
      byName[key] = topic.copyWith(status: TopicMasteryStatus.strong);
      continue;
    }
    if (existing.status == TopicMasteryStatus.weak) {
      byName[key] = existing.copyWith(
        status: TopicMasteryStatus.strong,
        mastery: existing.mastery > topic.mastery ? existing.mastery : topic.mastery,
      );
    }
  }

  return byName.values.toList(growable: false);
}

String _topicName(Map<String, dynamic> json) {
  final raw = (json['topic_path'] ??
          json['topic'] ??
          json['name'] ??
          json['title'] ??
          json['weak_topic'] ??
          json['subject_id'] ??
          json['id'] ??
          'Topic')
      .toString()
      .trim();
  return raw.isEmpty ? 'Topic' : raw;
}

int _pct(Object? value) {
  if (value is num) {
    final n = value.toDouble();
    if (n <= 1) return (n * 100).round().clamp(0, 100);
    return n.round().clamp(0, 100);
  }
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null) return 0;
  if (parsed <= 1) return (parsed * 100).round().clamp(0, 100);
  return parsed.round().clamp(0, 100);
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
