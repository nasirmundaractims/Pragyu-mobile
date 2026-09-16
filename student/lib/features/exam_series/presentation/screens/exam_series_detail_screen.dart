import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/exam_series/data/exam_series_repository.dart';
import 'package:student_mobile/features/exam_series/domain/exam_series_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

/// S-67 Exam Series detail — pack rank and assessments.
class ExamSeriesDetailScreen extends StatefulWidget {
  const ExamSeriesDetailScreen({
    super.key,
    required this.args,
    this.seriesRepository,
  });

  final ExamSeriesDetailArgs args;
  final ExamSeriesGateway? seriesRepository;

  @override
  State<ExamSeriesDetailScreen> createState() => _ExamSeriesDetailScreenState();
}

class _ExamSeriesDetailScreenState extends State<ExamSeriesDetailScreen> {
  late final ExamSeriesGateway _repo =
      widget.seriesRepository ?? ExamSeriesRepository();

  bool _loading = true;
  String? _error;
  ExamSeriesDetailSnapshot? _snapshot;

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
      final snapshot = await _repo.loadDetail(widget.args);
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
            : 'Unable to load this exam series.';
      });
    }
  }

  void _takeTest(ExamSeriesItem item) {
    Navigator.of(context).pushNamed(
      AppRoutes.assessmentDetail,
      arguments: AssessmentDetailArgs(
        assessmentId: item.assessmentId,
        title: item.displayTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final title = snapshot?.pack.title ?? widget.args.title ?? 'Test series';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
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
                              _HeaderCard(pack: snapshot.pack),
                              const SizedBox(height: 14),
                              _RankCard(
                                rank: snapshot.rank,
                                unavailable: snapshot.rankUnavailable,
                              ),
                              const SizedBox(height: 14),
                              _AssessmentsCard(
                                items: snapshot.pack.items,
                                onTakeTest: _takeTest,
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
  const _HeaderCard({required this.pack});

  final ExamSeriesPack pack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pack.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (pack.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              pack.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
          if (pack.organizationName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'From ${pack.organizationName}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.unavailable,
  });

  final ExamSeriesRank? rank;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your series rank',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (unavailable)
            const Text(
              'Rank is unavailable right now. You can still take the included tests.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          else if (rank?.hasRank == true) ...[
            Row(
              children: [
                Expanded(
                  child: _RankMetric(
                    label: 'Rank',
                    value: '${rank!.rank}',
                  ),
                ),
                Expanded(
                  child: _RankMetric(
                    label: 'Total marks',
                    value: rank!.totalMarks == null
                        ? '—'
                        : '${rank!.totalMarks!.round()}',
                  ),
                ),
                Expanded(
                  child: _RankMetric(
                    label: 'Cohort',
                    value: '${rank!.cohortSize}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              rank!.disclosureBlurb,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ] else
            Text(
              rank?.message ??
                  'Ranks appear here after the organisation admin discloses marks for exams in this series.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _RankMetric extends StatelessWidget {
  const _RankMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _AssessmentsCard extends StatelessWidget {
  const _AssessmentsCard({
    required this.items,
    required this.onTakeTest,
  });

  final List<ExamSeriesItem> items;
  final ValueChanged<ExamSeriesItem> onTakeTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assessments',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'No assessments in this series.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].displayTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].itemTypeLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: items[i].assessmentId.isEmpty
                        ? null
                        : () => onTakeTest(items[i]),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Take test'),
                  ),
                ],
              ),
            ],
        ],
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
