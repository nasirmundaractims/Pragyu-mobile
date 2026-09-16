import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// S-49 Past results / submissions hub — attempts + score reports.
class PastResultsScreen extends StatefulWidget {
  const PastResultsScreen({
    super.key,
    this.testsRepository,
  });

  final TestsGateway? testsRepository;

  @override
  State<PastResultsScreen> createState() => _PastResultsScreenState();
}

class _PastResultsScreenState extends State<PastResultsScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  String? _error;
  PastResultsSnapshot? _snapshot;
  PastResultsSegment _segment = PastResultsSegment.attempts;
  SubmissionHistoryTab _tab = SubmissionHistoryTab.all;
  String _query = '';

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
      final snapshot = await _tests.loadPastResults();
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
            : 'Unable to load your attempts.';
      });
    }
  }

  void _openSubmission(SubmissionSummary item) {
    final title = _snapshot?.titleFor(item.assessmentId);
    if (SubmissionPipeline.isReady(item.status)) {
      Navigator.of(context).pushNamed(
        AppRoutes.resultFeedback,
        arguments: ResultFeedbackArgs(
          submissionId: item.id,
          assessmentId: item.assessmentId,
          title: title,
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.submissionStatus,
      arguments: SubmissionStatusArgs(
        submissionId: item.id,
        assessmentId: item.assessmentId,
        title: title,
        initialStatus: item.status,
        includesMedia: submissionIncludesMedia(item),
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
          title: const Text('My attempts'),
        ),
        body: SafeArea(
          child: _loading && _snapshot == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Track uploaded answers and open score reports.',
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _SegmentSwitch(
                        segment: _segment,
                        onChanged: (value) =>
                            setState(() => _segment = value),
                      ),
                      const SizedBox(height: 16),
                      if (_snapshot != null) ...[
                        if (_segment == PastResultsSegment.attempts)
                          ..._buildAttemptsBody(_snapshot!)
                        else
                          ..._buildScoresBody(_snapshot!),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildAttemptsBody(PastResultsSnapshot snapshot) {
    final filtered = snapshot.filteredAttempts(_tab, query: _query);

    return [
      _SummaryGrid(
        items: [
          _SummaryTile(
            label: 'Total',
            value: '${snapshot.attempts.length}',
            active: _tab == SubmissionHistoryTab.all,
            onTap: () => setState(() => _tab = SubmissionHistoryTab.all),
          ),
          _SummaryTile(
            label: 'Processing',
            value: '${snapshot.processingCount}',
            active: _tab == SubmissionHistoryTab.processing,
            onTap: () =>
                setState(() => _tab = SubmissionHistoryTab.processing),
          ),
          _SummaryTile(
            label: 'Feedback',
            value: '${snapshot.feedbackReadyCount}',
            active: _tab == SubmissionHistoryTab.feedback,
            onTap: () => setState(() => _tab = SubmissionHistoryTab.feedback),
          ),
          _SummaryTile(
            label: 'Completed',
            value: '${snapshot.completedCount}',
            active: _tab == SubmissionHistoryTab.completed,
            onTap: () =>
                setState(() => _tab = SubmissionHistoryTab.completed),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: 'Search attempts',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.brandSoft),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.brandSoft),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (snapshot.attempts.isEmpty)
        const _EmptyCard(
          title: 'No attempts yet',
          message: 'Submit a test to see your uploads and progress here.',
        )
      else if (filtered.isEmpty)
        const _EmptyCard(
          title: 'Nothing in this view',
          message: 'Try another tab or clear your search.',
        )
      else
        ...filtered.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AttemptTile(
              title: snapshot.titleFor(item.assessmentId),
              item: item,
              onTap: () => _openSubmission(item),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildScoresBody(PastResultsSnapshot snapshot) {
    final scores = snapshot.scores;

    return [
      _SummaryGrid(
        items: [
          _SummaryTile(
            label: 'Evaluated',
            value: '${scores.length}',
            active: true,
            onTap: () {},
          ),
          _SummaryTile(
            label: 'Average',
            value: formatPercent(snapshot.averagePercentage),
            active: false,
            onTap: () {},
          ),
          _SummaryTile(
            label: 'Best',
            value: formatPercent(snapshot.bestPercentage),
            active: false,
            onTap: () {},
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (scores.isEmpty)
        const _EmptyCard(
          title: 'No scores yet',
          message: 'Finished tests appear here once AI evaluation completes.',
        )
      else ...[
        const Text(
          'Score reports',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        ...scores.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScoreTile(
              title: snapshot.titleFor(item.assessmentId),
              item: item,
              onTap: () => _openSubmission(item),
            ),
          ),
        ),
      ],
    ];
  }
}

class _SegmentSwitch extends StatelessWidget {
  const _SegmentSwitch({
    required this.segment,
    required this.onChanged,
  });

  final PastResultsSegment segment;
  final ValueChanged<PastResultsSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Attempts',
              selected: segment == PastResultsSegment.attempts,
              onTap: () => onChanged(PastResultsSegment.attempts),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Scores',
              selected: segment == PastResultsSegment.scores,
              onTap: () => onChanged(PastResultsSegment.scores),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummaryTile> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.brandSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.brand : AppColors.brandSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({
    required this.title,
    required this.item,
    required this.onTap,
  });

  final String title;
  final SubmissionSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stamp = item.submittedAt ?? item.updatedAt;
    final bucket = bucketSubmission(item);
    final badge = switch (bucket) {
      SubmissionHistoryBucket.processing => ('Processing', AppColors.accent),
      SubmissionHistoryBucket.feedback => ('Feedback ready', AppColors.success),
      SubmissionHistoryBucket.completed => ('Completed', AppColors.brand),
      SubmissionHistoryBucket.other =>
        SubmissionPipeline.isFailed(item.status)
            ? ('Needs attention', AppColors.danger)
            : (item.statusLabel, AppColors.muted),
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
            border: Border.all(color: AppColors.brandSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badge.$2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attempt ${item.attemptNumber} · ${formatRelativeTime(stamp)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (SubmissionPipeline.isReady(item.status))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatScorePair(item.totalScore, item.maxScore),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                    Text(
                      formatPercent(item.percentage),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.title,
    required this.item,
    required this.onTap,
  });

  final String title;
  final SubmissionSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grade = deriveAiGrade(item.percentage);
    final stamp = item.evaluatedAt ?? item.submittedAt;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Grade $grade',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Attempt ${item.attemptNumber} · Evaluated ${formatRelativeTime(stamp)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    formatScorePair(item.totalScore, item.maxScore),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatPercent(item.percentage),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Open report',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.brand,
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
