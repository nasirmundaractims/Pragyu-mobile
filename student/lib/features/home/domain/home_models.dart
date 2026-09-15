import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';

class HomeLecture {
  const HomeLecture({
    required this.id,
    required this.title,
    this.subjectName,
    this.courseName,
    this.lectureType,
    this.startsAt,
    this.sessionStatus,
  });

  final String id;
  final String title;
  final String? subjectName;
  final String? courseName;
  final String? lectureType;
  final DateTime? startsAt;
  final String? sessionStatus;

  bool get isLiveNow =>
      sessionStatus == 'live' || sessionStatus == 'waiting';

  factory HomeLecture.fromJson(Map<String, dynamic> json) {
    final schedule = json['live_schedule'];
    final session = json['live_session'];
    DateTime? startsAt;
    if (schedule is Map && schedule['starts_at'] != null) {
      startsAt = DateTime.tryParse(schedule['starts_at'].toString())?.toLocal();
    }
    return HomeLecture(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Class',
      subjectName: json['subject_name']?.toString(),
      courseName: json['course_name']?.toString(),
      lectureType: json['lecture_type']?.toString(),
      startsAt: startsAt,
      sessionStatus: session is Map ? session['status']?.toString() : null,
    );
  }
}

class HomeAssessment {
  const HomeAssessment({
    required this.id,
    required this.title,
    this.deadlineAt,
    this.due,
  });

  final String id;
  final String title;
  final DateTime? deadlineAt;
  final DueState? due;

  factory HomeAssessment.fromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final deadlineRaw = json['deadline_at']?.toString();
    return HomeAssessment(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Assessment',
      deadlineAt: deadlineRaw == null
          ? null
          : DateTime.tryParse(deadlineRaw)?.toLocal(),
      due: deriveDueState(deadlineRaw, now: now),
    );
  }
}

class HomeSnapshot {
  const HomeSnapshot({
    required this.user,
    this.nextLecture,
    this.dueAssessments = const [],
    this.unreadCount = 0,
  });

  final AuthUser user;
  final HomeLecture? nextLecture;
  final List<HomeAssessment> dueAssessments;
  final int unreadCount;
}

class TodaySnapshot {
  const TodaySnapshot({
    required this.day,
    this.classes = const [],
    this.deadlines = const [],
  });

  final DateTime day;
  final List<HomeLecture> classes;
  final List<HomeAssessment> deadlines;

  bool get isEmpty => classes.isEmpty && deadlines.isEmpty;
}

bool isSameLocalDay(DateTime a, DateTime b) {
  final left = a.toLocal();
  final right = b.toLocal();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
