import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/exam_workspace/data/exam_workspace_repository.dart';
import 'package:student_mobile/features/exam_workspace/domain/exam_workspace_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// S-66 Exam Workspace — practice hub and exam readiness.
class ExamWorkspaceScreen extends StatefulWidget {
  const ExamWorkspaceScreen({
    super.key,
    this.workspaceRepository,
  });

  final ExamWorkspaceGateway? workspaceRepository;

  @override
  State<ExamWorkspaceScreen> createState() => _ExamWorkspaceScreenState();
}

class _ExamWorkspaceScreenState extends State<ExamWorkspaceScreen> {
  late final ExamWorkspaceGateway _repo =
      widget.workspaceRepository ?? ExamWorkspaceRepository();

  bool _loading = true;
  String? _error;
  ExamWorkspaceSnapshot? _snapshot;

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
      final snapshot = await _repo.loadWorkspace();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load exam workspace.';
      });
    }
  }

  void _openAssessment(ExamPracticeSet item) {
    Navigator.of(context).pushNamed(
      AppRoutes.assessmentDetail,
      arguments: AssessmentDetailArgs(
        assessmentId: item.id,
        title: item.title,
      ),
    );
  }

  void _openSubmission(ExamRecentAttempt item) {
    if (SubmissionPipeline.isReady(item.submission.status)) {
      Navigator.of(context).pushNamed(
        AppRoutes.resultFeedback,
        arguments: ResultFeedbackArgs(submissionId: item.submission.id),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.submissionStatus,
      arguments: SubmissionStatusArgs(
        submissionId: item.submission.id,
        assessmentId: item.submission.assessmentId,
        title: item.title,
      ),
    );
  }

  String _factorPct(Map<String, dynamic> factors, List<String> keys) {
    for (final key in keys) {
      final raw = factors[key];
      if (raw is num) {
        final n = raw.toDouble();
        return '${(n <= 1 ? n * 100 : n).round()}%';
      }
      final parsed = double.tryParse(raw?.toString() ?? '');
      if (parsed != null) {
        return '${(parsed <= 1 ? parsed * 100 : parsed).round()}%';
      }
    }
    return '—';
  }

  String _factorText(Map<String, dynamic> factors, List<String> keys) {
    for (final key in keys) {
      final value = factors[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Building';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Exam Workspace'),
          actions: [
            IconButton(
              tooltip: 'Recommendations',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.recommendations),
              icon: const Icon(Icons.lightbulb_outline),
            ),
          ],
        ),
        body: SafeArea(
          child: _loading && snapshot == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && snapshot == null
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
                            if (snapshot != null) ...[
                              _HeaderCard(snapshot: snapshot),
                              const SizedBox(height: 14),
                              _SummaryGrid(snapshot: snapshot),
                              const SizedBox(height: 14),
                              _QuickActions(
                                onPastResults: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.pastResults),
                                onMentor: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.aiMentor),
                                onPlanner: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.studyPlanner),
                              ),
                              const SizedBox(height: 14),
                              _ReadinessCard(
                                snapshot: snapshot,
                                confidence: _factorPct(
                                  snapshot.readinessFactors,
                                  const ['confidence', 'confidence_score'],
                                ),
                                level: _factorText(
                                  snapshot.readinessFactors,
                                  const [
                                    'preparation_level',
                                    'level',
                                    'band',
                                  ],
                                ),
                                estimated: snapshot.readinessPct != null
                                    ? '${snapshot.readinessPct}%'
                                    : _factorPct(
                                        snapshot.readinessFactors,
                                        const [
                                          'estimated_readiness',
                                          'estimated_exam_readiness',
                                        ],
                                      ),
                                onWeakTopics: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.weakTopics),
                              ),
                              const SizedBox(height: 14),
                              _PracticeSection(
                                snapshot: snapshot,
                                onStart: _openAssessment,
                                onBookmarks: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.notesBookmarks),
                              ),
                              const SizedBox(height: 14),
                              _CoachActions(
                                actions: snapshot.display.coachActions,
                                onTap: (_) => Navigator.of(context)
                                    .pushNamed(AppRoutes.aiMentor),
                              ),
                              const SizedBox(height: 14),
                              _RoadmapCard(
                                steps: snapshot.display.roadmap,
                              ),
                              const SizedBox(height: 14),
                              _RecommendationsCard(
                                items: snapshot.recommendations,
                                onOpenAll: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.recommendations),
                              ),
                              const SizedBox(height: 14),
                              _TimelineCard(events: snapshot.timeline),
                              const SizedBox(height: 14),
                              _RecentActivityCard(
                                attempts: snapshot.recentAttempts,
                                onOpen: _openSubmission,
                                onFeedback: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.notesBookmarks),
                                onRecommendations: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.recommendations),
                              ),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.snapshot});

  final ExamWorkspaceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final from = Color(snapshot.display.accent.from.argb);
    final to = Color(snapshot.display.accent.to.argb);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exam Workspace · ${snapshot.exam.source.label}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.display.exam.hubTitle,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.display.subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.snapshot});

  final ExamWorkspaceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Upcoming', '${snapshot.upcoming.length}'),
      ('Pending eval', '${snapshot.pendingCount}'),
      (
        'Average score',
        snapshot.averageScore == null
            ? '—'
            : '${snapshot.averageScore!.round()}%',
      ),
      (
        'Readiness',
        snapshot.readinessPct == null ? '—' : '${snapshot.readinessPct}%',
      ),
      ('Weak topics', '${snapshot.weakTopics.length}'),
      ('Strong topics', '${snapshot.strongTopics.length}'),
      ('Streak', '${snapshot.streak}d'),
      ('Revision due', '${snapshot.revisionDue}'),
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
                width: width,
                child: _Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.$1.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onPastResults,
    required this.onMentor,
    required this.onPlanner,
  });

  final VoidCallback onPastResults;
  final VoidCallback onMentor;
  final VoidCallback onPlanner;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'Upload Answer',
        'Submit answers for AI evaluation',
        Icons.upload_file_outlined,
        onPastResults,
      ),
      (
        'Open AI Coach',
        'Guidance on weak topics and structure',
        Icons.auto_awesome_outlined,
        onMentor,
      ),
      (
        'Generate Plan',
        'Build a focused study schedule',
        Icons.calendar_month_outlined,
        onPlanner,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: actions[i].$4,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(actions[i].$3, color: AppColors.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actions[i].$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            actions[i].$2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.snapshot,
    required this.confidence,
    required this.level,
    required this.estimated,
    required this.onWeakTopics,
  });

  final ExamWorkspaceSnapshot snapshot;
  final String confidence;
  final String level;
  final String estimated;
  final VoidCallback onWeakTopics;

  @override
  Widget build(BuildContext context) {
    final pct = snapshot.readinessPct ?? 0;
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Exam readiness'),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (pct.clamp(0, 100)) / 100,
                      strokeWidth: 8,
                      backgroundColor: AppColors.brandSoft,
                      color: AppColors.brand,
                    ),
                    Text(
                      snapshot.readinessPct == null
                          ? '—'
                          : '${snapshot.readinessPct}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(title: 'Confidence', value: confidence),
                    _MetricChip(title: 'Level', value: level),
                    _MetricChip(title: 'Estimated', value: estimated),
                    _MetricChip(
                      title: 'Topic mastery',
                      value: '${snapshot.strongTopics.length} strong',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (snapshot.readinessUnavailable) ...[
            const SizedBox(height: 10),
            const Text(
              'Readiness is unavailable right now. Practice sets below still work.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: _SectionLabel('Weak areas')),
              TextButton(
                onPressed: onWeakTopics,
                child: const Text('See all'),
              ),
            ],
          ),
          _ChipWrap(items: snapshot.weakTopics, tone: _ChipTone.weak),
          const SizedBox(height: 12),
          const _SectionLabel('Strong areas'),
          const SizedBox(height: 6),
          _ChipWrap(items: snapshot.strongTopics, tone: _ChipTone.strong),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 0.6,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChipTone { weak, strong }

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items, required this.tone});

  final List<String> items;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No data yet.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }
    final bg = tone == _ChipTone.weak
        ? const Color(0x14C0392B)
        : const Color(0x141F8A5B);
    final fg = tone == _ChipTone.weak ? AppColors.danger : AppColors.success;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items.take(8))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
      ],
    );
  }
}

class _PracticeSection extends StatelessWidget {
  const _PracticeSection({
    required this.snapshot,
    required this.onStart,
    required this.onBookmarks,
  });

  final ExamWorkspaceSnapshot snapshot;
  final ValueChanged<ExamPracticeSet> onStart;
  final VoidCallback onBookmarks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Practice hub',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Available practice for ${snapshot.display.exam.label}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final type in snapshot.display.practiceTypes)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 42) / 2,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: type.id == 'bookmarks' || type.id == 'saved'
                        ? onBookmarks
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${snapshot.practiceTypeCount(type.id)} sets',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Available practice sets'),
              const SizedBox(height: 8),
              if (snapshot.practiceSets.isEmpty)
                Text(
                  'No ${snapshot.display.exam.label}-tagged assessments yet. '
                  'Showing all published practice when pattern is General.',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                )
              else
                ...[
                  for (var i = 0;
                      i < snapshot.practiceSets.length && i < 8;
                      i++) ...[
                    if (i > 0) const Divider(height: 18),
                    _PracticeRow(
                      item: snapshot.practiceSets[i],
                      onStart: () => onStart(snapshot.practiceSets[i]),
                    ),
                  ],
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({required this.item, required this.onStart});

  final ExamPracticeSet item;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.metaLine,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class _CoachActions extends StatelessWidget {
  const _CoachActions({required this.actions, required this.onTap});

  final List<CoachAction> actions;
  final ValueChanged<CoachAction> onTap;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.brand),
              SizedBox(width: 6),
              _SectionLabel('AI Coach'),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(actions[i]),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          actions[i].label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.steps});

  final List<RoadmapStep> steps;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Study roadmap'),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.ink,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        steps[i].description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  const _RecommendationsCard({
    required this.items,
    required this.onOpenAll,
  });

  final List<ExamRecommendationPreview> items;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 6),
              _SectionLabel('Recommendations'),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'Recommendations appear from weak topics, assessments, revision, and AI feedback.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenAll,
              child: const Text('Open all'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<ExamTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Timeline'),
          const SizedBox(height: 8),
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        events[i].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        events[i].detail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        events[i].meta.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.attempts,
    required this.onOpen,
    required this.onFeedback,
    required this.onRecommendations,
  });

  final List<ExamRecentAttempt> attempts;
  final ValueChanged<ExamRecentAttempt> onOpen;
  final VoidCallback onFeedback;
  final VoidCallback onRecommendations;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Recent activity'),
          const SizedBox(height: 8),
          if (attempts.isEmpty)
            const Text(
              'Practice attempts will appear here.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          else
            for (var i = 0; i < attempts.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attempts[i].isEvaluated
                              ? 'Recent evaluation'
                              : 'Recent practice',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '${attempts[i].title} · ${attempts[i].submission.status}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onOpen(attempts[i]),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: onFeedback,
                child: const Text('AI feedback'),
              ),
              OutlinedButton(
                onPressed: onRecommendations,
                child: const Text('Recommendations'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A142033),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: AppColors.muted,
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
