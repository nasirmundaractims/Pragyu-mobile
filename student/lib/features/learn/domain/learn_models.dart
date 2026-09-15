/// S-20 My learning — enrolled course row from account/courses.
class LearningCourse {
  const LearningCourse({
    required this.courseId,
    required this.title,
    this.enrollmentId,
    this.programId,
    this.programName,
    this.batchName,
    this.status,
    this.isActive = false,
    this.progressPercent,
  });

  final String courseId;
  final String title;
  final String? enrollmentId;
  final String? programId;
  final String? programName;
  final String? batchName;
  final String? status;
  final bool isActive;
  final int? progressPercent;

  String get subtitle {
    final parts = <String>[
      if (programName != null &&
          programName!.isNotEmpty &&
          programName != title)
        programName!,
      if (batchName != null && batchName!.isNotEmpty) batchName!,
    ];
    return parts.join(' · ');
  }

  String get statusLabel {
    if (isActive) return 'Active';
    final raw = status?.trim();
    if (raw == null || raw.isEmpty) return 'Inactive';
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class MyLearningSnapshot {
  const MyLearningSnapshot({this.courses = const []});

  final List<LearningCourse> courses;

  bool get isEmpty => courses.isEmpty;
}
