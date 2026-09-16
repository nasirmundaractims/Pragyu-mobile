import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/attendance/domain/attendance_models.dart';

void main() {
  test('AttendanceSummary parses counts and records', () {
    final summary = AttendanceSummary.fromJson(
      {
        'student_profile_id': 'sp-1',
        'attendance_percent': 86.4,
        'counts': {
          'present': 10,
          'absent': 1,
          'late': 2,
          'excused': 1,
          'total': 14,
        },
        'records': [
          {
            'id': 'r1',
            'attendance_date': '2026-09-15',
            'status': 'present',
          },
          {
            'id': 'r2',
            'attendance_date': '2026-09-14',
            'status': 'late',
            'reason': 'Bus delay',
          },
        ],
      },
      studentProfileId: 'sp-1',
    );

    expect(summary.rateLabel, '86%');
    expect(summary.counts.present, 10);
    expect(summary.recentMarks.length, 2);
    expect(summary.recentMarks.first.status, AttendanceStatus.present);
    expect(summary.recentMarks.last.statusLabel, 'Late');
    expect(summary.recentMarks.last.reason, 'Bus delay');
  });

  test('AttendanceStatus maps unknown values', () {
    expect(AttendanceStatusX.fromRaw('EXCUSED'), AttendanceStatus.excused);
    expect(AttendanceStatusX.fromRaw('mystery'), AttendanceStatus.other);
  });
}
