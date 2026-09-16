import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/attendance/data/attendance_repository.dart';
import 'package:student_mobile/features/attendance/domain/attendance_models.dart';

/// S-68 My Attendance — present, absent, late, and excused marks.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.attendanceRepository,
  });

  final AttendanceGateway? attendanceRepository;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceGateway _repo =
      widget.attendanceRepository ?? AttendanceRepository();

  bool _loading = true;
  String? _error;
  bool _missingProfile = false;
  AttendanceSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _missingProfile = false;
    });
    try {
      final summary = await _repo.loadSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on MissingStudentProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _missingProfile = true;
        _error = error.message;
        _summary = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : "Couldn't load attendance. Ask your institute if attendance tracking is turned on, then try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Attendance'),
        ),
        body: SafeArea(
          child: _loading && summary == null && !_missingProfile && _error == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _missingProfile
                  ? _MissingProfileBody(message: _error ?? 'Link a student profile to view your attendance.')
                  : _error != null && summary == null
                      ? _ErrorBody(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          color: AppColors.brand,
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'See present, absent, late, and excused marks from your academy.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.muted,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (summary != null) ...[
                                  _StatsGrid(summary: summary),
                                  const SizedBox(height: 18),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.event_available_outlined,
                                        size: 18,
                                        color: AppColors.brand,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Recent marks',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (summary.recentMarks.isEmpty)
                                    const _EmptyRecords()
                                  else
                                    for (final record in summary.recentMarks) ...[
                                      _RecordRow(record: record),
                                      const SizedBox(height: 8),
                                    ],
                                ],
                              ],
                            ),
                          ),
                        ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        'Attendance rate',
        summary.rateLabel,
        'Overall present rate',
      ),
      (
        'Present',
        '${summary.counts.present}',
        'Marked present',
      ),
      (
        'Absent',
        '${summary.counts.absent}',
        'Missed classes',
      ),
      (
        'Late',
        '${summary.counts.late}',
        'Arrived late',
      ),
      (
        'Excused',
        '${summary.counts.excused}',
        'Approved leave',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: card.$1 == 'Attendance rate'
                    ? constraints.maxWidth
                    : width,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.$1.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.$2,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.$3,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(record.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              record.dateLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tone.$1,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              record.statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tone.$2,
              ),
            ),
          ),
          if (record.reason != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                record.reason!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _statusTone(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46));
      case AttendanceStatus.absent:
        return (const Color(0xFFFEE2E2), const Color(0xFF9F1239));
      case AttendanceStatus.late:
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
      case AttendanceStatus.excused:
        return (const Color(0xFFE0F2FE), const Color(0xFF075985));
      case AttendanceStatus.other:
        return (AppColors.brandSoft, AppColors.brand);
    }
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x33142033),
          style: BorderStyle.solid,
        ),
      ),
      child: const Column(
        children: [
          Text(
            'No attendance records yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'When your academy marks attendance, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MissingProfileBody extends StatelessWidget {
  const _MissingProfileBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 40, color: AppColors.brand),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Couldn't load attendance",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
