import 'package:flutter/material.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';

/// Opens the correct lecture player for [lecture] (live lobby or recorded).
void openCourseLecture(BuildContext context, LectureItem lecture) {
  if (lecture.nextScreenId == 'S-24') {
    Navigator.of(context).pushNamed(
      AppRoutes.liveLobby,
      arguments: LiveLobbyArgs(
        lectureId: lecture.id,
        title: lecture.title,
      ),
    );
    return;
  }

  if (lecture.nextScreenId == 'S-26') {
    Navigator.of(context).pushNamed(
      AppRoutes.recordedLecture,
      arguments: RecordedLectureArgs(
        lectureId: lecture.id,
        title: lecture.title,
      ),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${lecture.title} — opens ${lecture.nextScreenId} when that screen ships.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Live / Upcoming / Recorded lecture list for a course (inline on course detail).
class CourseLecturesSection extends StatelessWidget {
  const CourseLecturesSection({
    super.key,
    required this.snapshot,
    bool? loading,
    this.error,
    this.onRetry,
    bool? embedded,
  })  : loading = loading ?? false,
        embedded = embedded ?? false;

  final LecturesSnapshot snapshot;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  /// When true, uses course-detail typography (no outer list padding).
  final bool embedded;

  int get _total {
    final live = snapshot.live;
    final upcoming = snapshot.upcoming;
    final recorded = snapshot.recorded;
    return live.length + upcoming.length + recorded.length;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = loading;
    final isEmpty = snapshot.isEmpty;

    if (isLoading && isEmpty && error == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (error != null && snapshot.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFC0392B), height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry lectures'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (embedded) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lectures',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
              ),
              if (_total > 0)
                Text(
                  '$_total',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A8499),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Live, upcoming & recorded classes',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A8499),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (snapshot.isEmpty)
          const Text(
            'No lectures published for this course yet.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Color(0xFF7A8499),
              height: 1.45,
            ),
          )
        else ...[
          if (snapshot.live.isNotEmpty) ...[
            const CourseLectureSectionHeader('Live now'),
            ...snapshot.live.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CourseLectureTile(
                  lecture: l,
                  kind: LectureKind.liveNow,
                  onTap: () => openCourseLecture(context, l),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (snapshot.upcoming.isNotEmpty) ...[
            const CourseLectureSectionHeader('Upcoming'),
            ...snapshot.upcoming.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CourseLectureTile(
                  lecture: l,
                  kind: LectureKind.upcoming,
                  onTap: () => openCourseLecture(context, l),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (snapshot.recorded.isNotEmpty) ...[
            const CourseLectureSectionHeader('Recorded'),
            ...snapshot.recorded.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CourseLectureTile(
                  lecture: l,
                  kind: LectureKind.recorded,
                  onTap: () => openCourseLecture(context, l),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class CourseLectureSectionHeader extends StatelessWidget {
  const CourseLectureSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A2B4C),
        ),
      ),
    );
  }
}

class CourseLectureTile extends StatelessWidget {
  const CourseLectureTile({
    super.key,
    required this.lecture,
    required this.kind,
    required this.onTap,
  });

  final LectureItem lecture;
  final LectureKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final live = kind == LectureKind.liveNow;
    final badge = switch (kind) {
      LectureKind.liveNow =>
        lecture.sessionStatus == 'waiting' ? 'Waiting' : 'Live',
      LectureKind.upcoming => 'Upcoming',
      LectureKind.recorded => 'Recorded',
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: live
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : const Color(0xFFE4EAF2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                kind == LectureKind.recorded
                    ? Icons.ondemand_video_outlined
                    : Icons.sensors_rounded,
                color: live ? AppColors.accent : AppColors.brand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: live ? AppColors.accent : const Color(0xFF7A8499),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lecture.title,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2B4C),
                        fontSize: 15,
                      ),
                    ),
                    if (lecture.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lecture.subtitle,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: Color(0xFF7A8499),
                        ),
                      ),
                    ],
                    if (lecture.startsAt != null &&
                        kind != LectureKind.recorded) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatStarts(lecture.startsAt!),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ] else if (lecture.durationSeconds != null &&
                        lecture.durationSeconds! > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(lecture.durationSeconds! / 60).ceil()} min',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7A8499)),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatStarts(DateTime startsAt) {
    final local = startsAt.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]} · $hour:$minute $suffix';
  }
}
