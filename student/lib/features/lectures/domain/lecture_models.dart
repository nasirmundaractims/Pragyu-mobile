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

/// Route args for S-24 Live class lobby.
class LiveLobbyArgs {
  const LiveLobbyArgs({
    required this.lectureId,
    this.title,
  });

  final String lectureId;
  final String? title;

  factory LiveLobbyArgs.fromObject(Object? raw) {
    if (raw is LiveLobbyArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return LiveLobbyArgs(
        lectureId: map['lectureId']?.toString() ??
            map['lecture_id']?.toString() ??
            '',
        title: map['title']?.toString(),
      );
    }
    if (raw is String) {
      return LiveLobbyArgs(lectureId: raw);
    }
    return const LiveLobbyArgs(lectureId: '');
  }
}

enum LiveSessionStatus {
  scheduled,
  waiting,
  live,
  ended,
  cancelled,
  unknown,
}

LiveSessionStatus parseLiveSessionStatus(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case 'scheduled':
      return LiveSessionStatus.scheduled;
    case 'waiting':
      return LiveSessionStatus.waiting;
    case 'live':
      return LiveSessionStatus.live;
    case 'ended':
      return LiveSessionStatus.ended;
    case 'cancelled':
    case 'canceled':
      return LiveSessionStatus.cancelled;
    default:
      return LiveSessionStatus.unknown;
  }
}

class LiveLobbySnapshot {
  const LiveLobbySnapshot({
    required this.lectureId,
    required this.title,
    this.courseName,
    this.subjectName,
    this.startsAt,
    this.endsAt,
    this.accessState,
    this.sessionStatus = LiveSessionStatus.unknown,
    this.rawSessionStatus,
    this.checkedIn = false,
    this.inWaitingRoom = false,
  });

  final String lectureId;
  final String title;
  final String? courseName;
  final String? subjectName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? accessState;
  final LiveSessionStatus sessionStatus;
  final String? rawSessionStatus;
  final bool checkedIn;
  final bool inWaitingRoom;

  bool get isLocked =>
      accessState == 'locked' || accessState == 'subscription_required';

  bool get canCheckIn =>
      !isLocked && sessionStatus == LiveSessionStatus.waiting;

  bool get canJoinClass =>
      !isLocked && sessionStatus == LiveSessionStatus.live;

  bool get canAct => canCheckIn || canJoinClass;

  String get statusLabel {
    if (isLocked) return 'Locked';
    switch (sessionStatus) {
      case LiveSessionStatus.waiting:
        return checkedIn ? 'Checked in' : 'Check-in open';
      case LiveSessionStatus.live:
        return 'Live now';
      case LiveSessionStatus.ended:
        return 'Ended';
      case LiveSessionStatus.cancelled:
        return 'Cancelled';
      case LiveSessionStatus.scheduled:
        return 'Scheduled';
      case LiveSessionStatus.unknown:
        return 'Not open yet';
    }
  }

  String get statusDetail {
    if (isLocked) {
      return 'This class is locked for your enrollment.';
    }
    switch (sessionStatus) {
      case LiveSessionStatus.waiting:
        return checkedIn || inWaitingRoom
            ? 'You’re checked in. Your teacher will let you in soon.'
            : 'The waiting room is open. Check in to reserve your seat.';
      case LiveSessionStatus.live:
        return 'Class is live. Join to enter the room.';
      case LiveSessionStatus.ended:
        return 'This live session has ended. Recordings may appear under Lectures.';
      case LiveSessionStatus.cancelled:
        return 'This live class was cancelled.';
      case LiveSessionStatus.scheduled:
      case LiveSessionStatus.unknown:
        return startsAt == null
            ? 'Waiting for the teacher to open the class.'
            : 'Class opens around the scheduled start time.';
    }
  }

  String get primaryActionLabel {
    if (canJoinClass) return 'Join class';
    if (canCheckIn) return 'Check in';
    return 'Not available';
  }

  LiveLobbySnapshot copyWith({
    bool? checkedIn,
    bool? inWaitingRoom,
    LiveSessionStatus? sessionStatus,
    String? rawSessionStatus,
  }) {
    return LiveLobbySnapshot(
      lectureId: lectureId,
      title: title,
      courseName: courseName,
      subjectName: subjectName,
      startsAt: startsAt,
      endsAt: endsAt,
      accessState: accessState,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      rawSessionStatus: rawSessionStatus ?? this.rawSessionStatus,
      checkedIn: checkedIn ?? this.checkedIn,
      inWaitingRoom: inWaitingRoom ?? this.inWaitingRoom,
    );
  }

  /// Human countdown or scheduled time.
  String countdownLabel({DateTime? now}) {
    final start = startsAt;
    if (start == null) return 'Start time TBD';
    final clock = now ?? DateTime.now();
    final diff = start.difference(clock);
    if (sessionStatus == LiveSessionStatus.live) {
      return 'Class in progress';
    }
    if (diff.inSeconds <= 0) {
      return 'Scheduled ${_formatClock(start)}';
    }
    if (diff.inHours >= 24) {
      final days = diff.inDays;
      return 'Starts in $days day${days == 1 ? '' : 's'}';
    }
    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      final mins = diff.inMinutes.remainder(60);
      return 'Starts in ${hours}h ${mins}m';
    }
    if (diff.inMinutes >= 1) {
      return 'Starts in ${diff.inMinutes} min';
    }
    return 'Starting soon';
  }

  static String _formatClock(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class LiveJoinResult {
  const LiveJoinResult({
    required this.inWaitingRoom,
    this.hasMediaToken = false,
    this.sessionStatus,
  });

  final bool inWaitingRoom;
  final bool hasMediaToken;
  final LiveSessionStatus? sessionStatus;
}
