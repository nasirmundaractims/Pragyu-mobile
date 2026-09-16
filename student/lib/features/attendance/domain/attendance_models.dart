/// S-68 My Attendance models.

enum AttendanceStatus { present, absent, late, excused, other }

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.excused:
        return 'Excused';
      case AttendanceStatus.other:
        return 'Marked';
    }
  }

  static AttendanceStatus fromRaw(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'excused':
        return AttendanceStatus.excused;
      default:
        return AttendanceStatus.other;
    }
  }
}

class AttendanceCounts {
  const AttendanceCounts({
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.excused = 0,
    this.total = 0,
  });

  final int present;
  final int absent;
  final int late;
  final int excused;
  final int total;

  factory AttendanceCounts.fromJson(Map<String, dynamic> json) {
    return AttendanceCounts(
      present: _int(json['present']) ?? 0,
      absent: _int(json['absent']) ?? 0,
      late: _int(json['late']) ?? 0,
      excused: _int(json['excused']) ?? 0,
      total: _int(json['total']) ?? 0,
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.attendanceDate,
    required this.status,
    this.reason,
    this.batchId,
    this.lectureId,
    this.slotKey,
    this.markedAt,
    this.rawStatus = '',
  });

  final String id;
  final String attendanceDate;
  final AttendanceStatus status;
  final String? reason;
  final String? batchId;
  final String? lectureId;
  final String? slotKey;
  final DateTime? markedAt;
  final String rawStatus;

  String get statusLabel {
    if (status != AttendanceStatus.other) return status.label;
    final raw = rawStatus.trim();
    if (raw.isEmpty) return '—';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String get dateLabel {
    final parsed = DateTime.tryParse(attendanceDate);
    if (parsed == null) {
      return attendanceDate.isEmpty ? '—' : attendanceDate;
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = parsed.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? '').toString();
    return AttendanceRecord(
      id: json['id']?.toString() ??
          '${json['attendance_date']}-${json['status']}',
      attendanceDate: (json['attendance_date'] ?? json['date'] ?? '').toString(),
      status: AttendanceStatusX.fromRaw(rawStatus),
      reason: _nullable(json['reason']?.toString()),
      batchId: json['batch_id']?.toString(),
      lectureId: json['lecture_id']?.toString(),
      slotKey: json['slot_key']?.toString(),
      markedAt: DateTime.tryParse(json['marked_at']?.toString() ?? ''),
      rawStatus: rawStatus,
    );
  }
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.studentProfileId,
    this.from,
    this.to,
    this.attendancePercent,
    this.counts = const AttendanceCounts(),
    this.records = const [],
  });

  final String studentProfileId;
  final String? from;
  final String? to;
  final double? attendancePercent;
  final AttendanceCounts counts;
  final List<AttendanceRecord> records;

  String get rateLabel {
    if (attendancePercent == null) return '—';
    return '${attendancePercent!.round()}%';
  }

  List<AttendanceRecord> get recentMarks =>
      records.length <= 40 ? records : records.sublist(0, 40);

  factory AttendanceSummary.fromJson(
    Map<String, dynamic> json, {
    required String studentProfileId,
  }) {
    final recordsRaw = json['records'];
    final records = <AttendanceRecord>[];
    if (recordsRaw is List) {
      for (final row in recordsRaw) {
        if (row is! Map) continue;
        records.add(
          AttendanceRecord.fromJson(
            row.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      }
    }

    return AttendanceSummary(
      studentProfileId: json['student_profile_id']?.toString() ??
          studentProfileId,
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      attendancePercent: _num(json['attendance_percent']),
      counts: AttendanceCounts.fromJson(_asMap(json['counts'])),
      records: records,
    );
  }
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

int? _int(Object? raw) {
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

double? _num(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

String? _nullable(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
