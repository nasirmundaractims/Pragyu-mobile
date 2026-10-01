import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/attendance/data/attendance_repository.dart';
import 'package:student_mobile/features/attendance/domain/attendance_models.dart';
import 'package:student_mobile/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:student_mobile/features/organization/data/memory_tenant_store.dart';

class _FakeAttendance implements AttendanceGateway {
  _FakeAttendance(this.summary, {this.throwMissing = false, this.throwError});

  final AttendanceSummary summary;
  final bool throwMissing;
  final Object? throwError;
  int loadCalls = 0;

  @override
  Future<AttendanceSummary> loadSummary() async {
    loadCalls += 1;
    if (throwMissing) {
      throw const MissingStudentProfileException();
    }
    if (throwError != null) {
      throw throwError!;
    }
    return summary;
  }
}

MemoryTenantStore _orgTenant() {
  final store = MemoryTenantStore();
  store.id = 'org-1';
  store.name = 'Demo Institute';
  store.type = 'institute';
  return store;
}

void main() {
  testWidgets('S-68 shows rate, counts, and recent marks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeAttendance(
      const AttendanceSummary(
        studentProfileId: 'sp-1',
        attendancePercent: 90,
        counts: AttendanceCounts(
          present: 8,
          absent: 1,
          late: 1,
          excused: 0,
          total: 10,
        ),
        records: [
          AttendanceRecord(
            id: 'r1',
            attendanceDate: '2026-09-15',
            status: AttendanceStatus.present,
          ),
          AttendanceRecord(
            id: 'r2',
            attendanceDate: '2026-09-14',
            status: AttendanceStatus.absent,
            reason: 'Sick',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttendanceScreen(
          attendanceRepository: fake,
          tenantStore: _orgTenant(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('90%'), findsOneWidget);
    expect(find.text('Present'), findsWidgets);
    expect(find.text('Recent marks'), findsOneWidget);
    expect(find.text('Sick'), findsOneWidget);
  });

  testWidgets('S-68 empty records state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttendanceScreen(
          attendanceRepository: _FakeAttendance(
            const AttendanceSummary(
              studentProfileId: 'sp-1',
              attendancePercent: null,
            ),
          ),
          tenantStore: _orgTenant(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('No attendance records yet'), findsOneWidget);
  });

  testWidgets('S-68 missing profile message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttendanceScreen(
          attendanceRepository: _FakeAttendance(
            const AttendanceSummary(studentProfileId: ''),
            throwMissing: true,
          ),
          tenantStore: _orgTenant(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Link a student profile'),
      findsOneWidget,
    );
  });

  testWidgets('S-68 individual workspace hides attendance data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeAttendance(
      const AttendanceSummary(studentProfileId: 'sp-1', attendancePercent: 90),
    );
    final tenant = MemoryTenantStore()
      ..id = 'ind-1'
      ..name = 'My Learning'
      ..type = 'individual';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttendanceScreen(
          attendanceRepository: fake,
          tenantStore: tenant,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.loadCalls, 0);
    expect(find.text('Attendance is for organisations'), findsOneWidget);
    expect(find.text('Join organisation'), findsOneWidget);
    expect(find.text('90%'), findsNothing);
  });
}
