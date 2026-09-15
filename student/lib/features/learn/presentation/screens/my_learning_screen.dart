import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';

/// S-20 My learning — enrolled courses / programs for the Learn tab.
class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({
    super.key,
    this.learnRepository,
  });

  final LearnGateway? learnRepository;

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends State<MyLearningScreen> {
  late final LearnGateway _learn =
      widget.learnRepository ?? LearnRepository();

  bool _loading = true;
  String? _error;
  MyLearningSnapshot? _snapshot;

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
      final snapshot = await _learn.loadMyLearning();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your courses. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openCourse(LearningCourse course) {
    Navigator.of(context).pushNamed(
      AppRoutes.courseDetail,
      arguments: CourseDetailArgs(
        courseId: course.courseId,
        title: course.title,
        programName: course.programName,
        batchName: course.batchName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('My learning'),
          actions: [
            IconButton(
              tooltip: 'Quick search',
              onPressed: () => showQuickSearchSheet(context),
              icon: const Icon(Icons.search_rounded, color: AppColors.ink),
            ),
          ],
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'Enrolled courses and programs in this institute.',
          style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        if (snapshot.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Text(
              'No enrolled courses yet.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
          )
        else
          ...snapshot.courses.map(
            (course) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CourseTile(
                course: course,
                onTap: () => _openCourse(course),
              ),
            ),
          ),
      ],
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.onTap,
  });

  final LearningCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = course.subtitle;

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
            border: Border.all(color: AppColors.brandSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusChip(
                          label: course.statusLabel,
                          active: course.isActive,
                        ),
                        if (course.progressPercent != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${course.progressPercent}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE6F5EE) : AppColors.brandSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.success : AppColors.muted,
        ),
      ),
    );
  }
}
