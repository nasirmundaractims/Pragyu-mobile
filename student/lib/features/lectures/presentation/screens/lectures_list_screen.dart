import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/lectures/presentation/widgets/course_lectures_section.dart';

/// S-23 Lectures list — live, upcoming, and recorded classes.
///
/// Still used for global (non-course) entry points. Course-scoped lectures
/// are shown inline on [CourseDetailScreen].
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

  @override
  Widget build(BuildContext context) {
    final scopedTitle = widget.args.courseTitle?.trim();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Lectures'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _load,
            child: _buildBody(scopedTitle),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String? courseTitle) {
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
        CourseLecturesSection(
          snapshot: snapshot,
          loading: _loading,
          error: _error,
          onRetry: _load,
        ),
      ],
    );
  }
}
