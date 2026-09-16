import 'package:student_mobile/features/home/domain/due_state.dart';

enum TestKind { exam, quiz, assignment, practice, other }

enum TestsFilter { all, dueSoon, practice }

class TestListItem {
  const TestListItem({
    required this.id,
    required this.title,
    this.type = TestKind.other,
    this.description,
    this.totalMarks,
    this.durationMinutes,
    this.questionsCount,
    this.scheduledAt,
    this.deadlineAt,
    this.due,
  });

  final String id;
  final String title;
  final TestKind type;
  final String? description;
  final int? totalMarks;
  final int? durationMinutes;
  final int? questionsCount;
  final DateTime? scheduledAt;
  final DateTime? deadlineAt;
  final DueState? due;

  String get typeLabel {
    switch (type) {
      case TestKind.exam:
        return 'Exam';
      case TestKind.quiz:
        return 'Quiz';
      case TestKind.assignment:
        return 'Assignment';
      case TestKind.practice:
        return 'Practice';
      case TestKind.other:
        return 'Test';
    }
  }

  String get subtitle {
    final parts = <String>[
      typeLabel,
      if (durationMinutes != null && durationMinutes! > 0)
        '$durationMinutes min',
      if (totalMarks != null) '$totalMarks marks',
      if (questionsCount != null && questionsCount! > 0)
        '$questionsCount Qs',
    ];
    return parts.join(' · ');
  }

  bool get isDueSoon => due?.isActionable ?? false;

  bool get isPractice => type == TestKind.practice || type == TestKind.quiz;

  /// Opens S-41 Assessment detail when that screen ships.
  String get nextScreenId => 'S-41';

  factory TestListItem.fromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final deadlineRaw = json['deadline_at']?.toString() ??
        json['closes_at']?.toString();
    final scheduledRaw = json['scheduled_at']?.toString();

    int? asInt(Object? raw) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '');
    }

    return TestListItem(
      id: json['id']?.toString() ?? '',
      title: (json['title']?.toString() ?? '').trim().isEmpty
          ? 'Untitled test'
          : json['title'].toString().trim(),
      type: _parseType(json['type']?.toString()),
      description: json['description']?.toString(),
      totalMarks: asInt(json['total_marks']),
      durationMinutes: asInt(json['duration_minutes']),
      questionsCount: asInt(json['questions_count']),
      scheduledAt: scheduledRaw == null
          ? null
          : DateTime.tryParse(scheduledRaw)?.toLocal(),
      deadlineAt: deadlineRaw == null
          ? null
          : DateTime.tryParse(deadlineRaw)?.toLocal(),
      due: deriveDueState(deadlineRaw, now: now),
    );
  }

  static TestKind _parseType(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'exam':
        return TestKind.exam;
      case 'quiz':
        return TestKind.quiz;
      case 'assignment':
        return TestKind.assignment;
      case 'practice':
        return TestKind.practice;
      default:
        return TestKind.other;
    }
  }
}

class TestsSnapshot {
  const TestsSnapshot({this.items = const []});

  final List<TestListItem> items;

  bool get isEmpty => items.isEmpty;

  List<TestListItem> filtered(TestsFilter filter) {
    switch (filter) {
      case TestsFilter.all:
        return items;
      case TestsFilter.dueSoon:
        return items.where((item) => item.isDueSoon).toList(growable: false);
      case TestsFilter.practice:
        return items.where((item) => item.isPractice).toList(growable: false);
    }
  }
}
