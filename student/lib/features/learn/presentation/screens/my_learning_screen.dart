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
          title: const Text('Learn'),
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
    final activeCount =
        snapshot.courses.where((course) => course.isActive).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Your enrolled courses and programs in this institute.',
          style: TextStyle(fontSize: 16, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        _SummaryCard(
          total: snapshot.courses.length,
          active: activeCount,
        ),
        const SizedBox(height: 18),
        if (snapshot.isEmpty)
          _EmptyState(
            onBrowse: () =>
                Navigator.of(context).pushNamed(AppRoutes.catalog),
            onLectures: () =>
                Navigator.of(context).pushNamed(AppRoutes.lecturesList),
          )
        else ...[
          const Text(
            'Courses',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...snapshot.courses.map(
            (course) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CourseTile(
                course: course,
                onTap: () => _openCourse(course),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.active,
  });

  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              total == 0
                  ? 'No courses enrolled yet'
                  : '$total course${total == 1 ? '' : 's'} · $active active',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          const Icon(
            Icons.menu_book_rounded,
            color: AppColors.brand,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onBrowse,
    required this.onLectures,
  });

  final VoidCallback onBrowse;
  final VoidCallback onLectures;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.school_outlined,
            size: 40,
            color: AppColors.brand,
          ),
          const SizedBox(height: 14),
          const Text(
            'No enrolled courses yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Live lectures can still appear on Home when your institute schedules them. Enroll in a course to unlock modules and lessons here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.45, fontSize: 15),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onBrowse,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Browse catalog'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onLectures,
            child: const Text('Open lectures'),
          ),
        ],
      ),
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
    final progress = (course.progressPercent ?? 0).clamp(0, 100);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brandSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(12),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(label: course.statusLabel, active: course.isActive),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 8,
                        backgroundColor: AppColors.brandSoft,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$progress%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE6F5EE) : AppColors.brandSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.success : AppColors.muted,
        ),
      ),
    );
  }
}
