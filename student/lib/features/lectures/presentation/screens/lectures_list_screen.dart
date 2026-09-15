import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';

/// S-23 Lectures list — live, upcoming, and recorded classes.
class LecturesListScreen extends StatefulWidget {
  const LecturesListScreen({
    super.key,
    this.args = const LecturesListArgs(),
    this.lecturesRepository,
  });

  final LecturesListArgs args;
  final LecturesGateway? lecturesRepository;

  @override
  State<LecturesListScreen> createState() => _LecturesListScreenState();
}

class _LecturesListScreenState extends State<LecturesListScreen> {
  late final LecturesGateway _lectures =
      widget.lecturesRepository ?? LecturesRepository();

  bool _loading = true;
  String? _error;
  LecturesSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _lectures.loadLectures(
        courseId: widget.args.courseId,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load lectures. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openLecture(LectureItem lecture) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${lecture.title} — opens ${lecture.nextScreenId} when that screen ships.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopedTitle = widget.args.courseTitle?.trim();
    final title = (scopedTitle != null && scopedTitle.isNotEmpty)
        ? 'Lectures'
        : 'Lectures';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.brand)),
        ],
      );
    }

    if (_error != null && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, height: 1.45),
          ),
        ],
      );
    }

    final snapshot = _snapshot!;
    final courseTitle = widget.args.courseTitle?.trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          courseTitle != null && courseTitle.isNotEmpty
              ? 'Live and recorded classes for $courseTitle.'
              : 'Live and recorded classes for your enrollments.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        if (snapshot.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text(
              'No lectures published yet.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          )
        else ...[
          if (snapshot.live.isNotEmpty) ...[
            const _SectionHeader('Live now'),
            ...snapshot.live.map((l) => _tile(l, LectureKind.liveNow)),
            const SizedBox(height: 8),
          ],
          if (snapshot.upcoming.isNotEmpty) ...[
            const _SectionHeader('Upcoming'),
            ...snapshot.upcoming.map((l) => _tile(l, LectureKind.upcoming)),
            const SizedBox(height: 8),
          ],
          if (snapshot.recorded.isNotEmpty) ...[
            const _SectionHeader('Recorded'),
            ...snapshot.recorded.map((l) => _tile(l, LectureKind.recorded)),
          ],
        ],
      ],
    );
  }

  Widget _tile(LectureItem lecture, LectureKind kind) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _LectureTile(
        lecture: lecture,
        kind: kind,
        onTap: () => _openLecture(lecture),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _LectureTile extends StatelessWidget {
  const _LectureTile({
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
      LectureKind.liveNow => lecture.sessionStatus == 'waiting'
          ? 'Waiting'
          : 'Live',
      LectureKind.upcoming => 'Upcoming',
      LectureKind.recorded => 'Recorded',
    };

    return Material(
      color: AppColors.surface,
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
                  : AppColors.brandSoft,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: live ? AppColors.accent : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lecture.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    if (lecture.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lecture.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    if (lecture.startsAt != null &&
                        kind != LectureKind.recorded) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatStarts(lecture.startsAt!),
                        style: const TextStyle(
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
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
