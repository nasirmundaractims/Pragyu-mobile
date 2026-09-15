import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';

/// S-21 Course detail — modules, progress, Continue CTA.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.args,
    this.learnRepository,
  });

  final CourseDetailArgs args;
  final LearnGateway? learnRepository;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final LearnGateway _learn =
      widget.learnRepository ?? LearnRepository();

  bool _loading = true;
  String? _error;
  CourseDetailSnapshot? _snapshot;

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
      final snapshot = await _learn.loadCourseDetail(widget.args);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load this course. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openLesson(CourseLesson lesson) {
    Navigator.of(context).pushNamed(
      AppRoutes.lessonPlayer,
      arguments: LessonDetailArgs(
        lessonId: lesson.id,
        courseId: _snapshot?.courseId ?? widget.args.courseId,
        title: lesson.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.displayTitle ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Course');

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
    final continueLesson = snapshot.continueLesson;
    final subtitle = snapshot.subtitle;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (subtitle.isNotEmpty) ...[
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
        ],
        _ProgressCard(progress: snapshot.progress),
        if (continueLesson != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openLesson(continueLesson),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                snapshot.progress.courseCompleted
                    ? 'Review: ${continueLesson.title}'
                    : 'Continue: ${continueLesson.title}',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.lecturesList,
                    arguments: LecturesListArgs(
                      courseId: snapshot.courseId,
                      courseTitle: snapshot.displayTitle,
                    ),
                  );
                },
                icon: const Icon(Icons.sensors_rounded),
                label: const Text('Lectures'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.brandSoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.studyMaterials,
                    arguments: StudyMaterialsListArgs(
                      courseId: snapshot.courseId,
                      courseTitle: snapshot.displayTitle,
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Materials'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.brandSoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Modules',          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (!snapshot.hasModules)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'No modules published in this course yet.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          )
        else
          ...snapshot.modules.map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModuleCard(
                module: module,
                onLessonTap: _openLesson,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final CourseProgressSummary progress;

  @override
  Widget build(BuildContext context) {
    final fraction = (progress.completionPercent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${progress.completionPercent}% complete',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${progress.completedLessons}/${progress.totalLessons} lessons',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              color: AppColors.accent,
              backgroundColor: AppColors.brandSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.onLessonTap,
  });

  final CourseModule module;
  final ValueChanged<CourseLesson> onLessonTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.brandSoft),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.brandSoft),
          ),
          title: Text(
            module.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            module.lessons.isEmpty
                ? 'No lessons'
                : '${module.completedCount}/${module.lessons.length} lessons',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          children: module.lessons.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No lessons in this module yet.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ]
              : module.lessons
                  .map(
                    (lesson) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        lesson.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        color: lesson.isCompleted
                            ? AppColors.success
                            : AppColors.brand,
                      ),
                      title: Text(
                        lesson.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        [
                          lesson.statusLabel,
                          if (lesson.topicPath != null &&
                              lesson.topicPath!.isNotEmpty)
                            lesson.topicPath,
                          if (lesson.estimatedMinutes != null)
                            '${lesson.estimatedMinutes} min',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                      ),
                      onTap: () => onLessonTap(lesson),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}
