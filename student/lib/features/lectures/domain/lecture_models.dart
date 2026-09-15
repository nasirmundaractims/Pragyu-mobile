/// Route args for S-23 Lectures list.
class LecturesListArgs {
  const LecturesListArgs({
    this.courseId,
    this.courseTitle,
  });

  final String? courseId;
  final String? courseTitle;

  factory LecturesListArgs.fromObject(Object? raw) {
    if (raw is LecturesListArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return LecturesListArgs(
        courseId:
            map['courseId']?.toString() ?? map['course_id']?.toString(),
        courseTitle:
            map['courseTitle']?.toString() ?? map['course_title']?.toString(),
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return LecturesListArgs(courseId: raw);
    }
    return const LecturesListArgs();
  }
}

enum LectureKind { liveNow, upcoming, recorded }

class LectureItem {
  const LectureItem({
    required this.id,
    required this.title,
    this.subjectName,
    this.courseName,
    this.courseId,
    this.lectureType,
    this.startsAt,
    this.sessionStatus,
    this.durationSeconds,
    this.accessState,
    this.hasVideo = false,
  });

  final String id;
  final String title;
  final String? subjectName;
  final String? courseName;
  final String? courseId;
  final String? lectureType;
  final DateTime? startsAt;
  final String? sessionStatus;
  final int? durationSeconds;
  final String? accessState;
  final bool hasVideo;

  bool get isLiveSession =>
      sessionStatus == 'live' || sessionStatus == 'waiting';

  bool get isLiveType =>
      (lectureType ?? '').toLowerCase() == 'live';

  String get subtitle {
    final parts = <String>[
      if (subjectName != null && subjectName!.isNotEmpty) subjectName!,
      if (courseName != null && courseName!.isNotEmpty) courseName!,
    ];
    return parts.join(' · ');
  }

  LectureKind classify({DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (isLiveSession) return LectureKind.liveNow;
    if (isLiveType && startsAt != null) {
      // Treat as upcoming until an hour after start (then fall to recorded).
      if (!startsAt!.isBefore(clock.subtract(const Duration(hours: 1)))) {
        return LectureKind.upcoming;
      }
    }
    return LectureKind.recorded;
  }

  /// Live/upcoming open S-24; recorded open S-26.
  String get nextScreenId {
    switch (classify()) {
      case LectureKind.liveNow:
      case LectureKind.upcoming:
        return 'S-24';
      case LectureKind.recorded:
        return 'S-26';
    }
  }

  factory LectureItem.fromJson(Map<String, dynamic> json) {
    final schedule = json['live_schedule'];
    final session = json['live_session'];
    final video = json['video'];
    DateTime? startsAt;
    if (schedule is Map && schedule['starts_at'] != null) {
      startsAt = DateTime.tryParse(schedule['starts_at'].toString())?.toLocal();
    }
    final durationRaw = json['duration_seconds'];
    int? durationSeconds;
    if (durationRaw is num) {
      durationSeconds = durationRaw.round();
    } else {
      durationSeconds = int.tryParse(durationRaw?.toString() ?? '');
    }

    return LectureItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Lecture',
      subjectName: json['subject_name']?.toString(),
      courseName: json['course_name']?.toString(),
      courseId: json['course_id']?.toString(),
      lectureType: json['lecture_type']?.toString(),
      startsAt: startsAt,
      sessionStatus: session is Map ? session['status']?.toString() : null,
      durationSeconds: durationSeconds,
      accessState: json['access_state']?.toString(),
      hasVideo: video is Map && video.isNotEmpty,
    );
  }
}

class LecturesSnapshot {
  const LecturesSnapshot({
    this.live = const [],
    this.upcoming = const [],
    this.recorded = const [],
  });

  final List<LectureItem> live;
  final List<LectureItem> upcoming;
  final List<LectureItem> recorded;

  bool get isEmpty =>
      live.isEmpty && upcoming.isEmpty && recorded.isEmpty;

  factory LecturesSnapshot.fromItems(
    List<LectureItem> items, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final live = <LectureItem>[];
    final upcoming = <LectureItem>[];
    final recorded = <LectureItem>[];

    for (final item in items) {
      switch (item.classify(now: clock)) {
        case LectureKind.liveNow:
          live.add(item);
        case LectureKind.upcoming:
          upcoming.add(item);
        case LectureKind.recorded:
          recorded.add(item);
      }
    }

    upcoming.sort((a, b) {
      final sa = a.startsAt;
      final sb = b.startsAt;
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sa.compareTo(sb);
    });

    recorded.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return LecturesSnapshot(
      live: live,
      upcoming: upcoming,
      recorded: recorded,
    );
  }
}
