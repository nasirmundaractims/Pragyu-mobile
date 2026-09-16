import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';

/// S-46 Result / feedback — score, breakdown, AI feedback.
class ResultFeedbackScreen extends StatefulWidget {
  const ResultFeedbackScreen({
    super.key,
    required this.args,
    this.testsRepository,
  });

  final ResultFeedbackArgs args;
  final TestsGateway? testsRepository;

  @override
  State<ResultFeedbackScreen> createState() => _ResultFeedbackScreenState();
}

class _ResultFeedbackScreenState extends State<ResultFeedbackScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  String? _error;
  ResultFeedbackSnapshot? _snapshot;

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
      final snapshot = await _tests.loadResultFeedback(widget.args);
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
            : 'Unable to load result feedback.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.title?.trim().isNotEmpty == true
        ? widget.args.title!.trim()
        : 'Result';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && _snapshot == null
                  ? _ErrorBody(message: _error!, onRetry: _load)
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
                          if (_snapshot != null) ..._buildBody(_snapshot!),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(ResultFeedbackSnapshot snapshot) {
    final feedback = snapshot.feedback;
    final evaluationSummary = snapshot.evaluation?.feedbackSummary;

    return [
      _ScoreHero(
        scoreLabel: snapshot.scoreLabel,
        percentageLabel: snapshot.percentageLabel,
        grade: snapshot.evaluation?.grade,
        attemptNumber: snapshot.submission.attemptNumber,
      ),
      const SizedBox(height: 20),
      _SectionTitle(title: 'Score breakdown'),
      const SizedBox(height: 10),
      if (snapshot.scores.isEmpty)
        const _MutedCard(
          child: Text(
            'Question scores appear when AI evaluation finishes.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        )
      else
        ...snapshot.scores.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final score = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScoreTile(index: index, score: score),
          );
        }),
      const SizedBox(height: 16),
      const _SectionTitle(title: 'Feedback'),
      const SizedBox(height: 10),
      if (feedback == null || !feedback.hasContent)
        _MutedCard(
          child: Text(
            evaluationSummary?.isNotEmpty == true
                ? evaluationSummary!
                : 'Detailed feedback appears after AI scoring completes.',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        )
      else ...[
        if (feedback.summary != null && feedback.summary!.isNotEmpty)
          _OverallFeedbackCard(summary: feedback.summary!),
        if (feedback.strengths.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BulletCard(
            title: 'Strengths',
            items: feedback.strengths,
            accent: AppColors.success,
          ),
        ],
        if (feedback.weaknesses.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BulletCard(
            title: 'Weaknesses',
            items: feedback.weaknesses,
            accent: AppColors.danger,
          ),
        ],
        if (feedback.improvementAreas.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BulletCard(
            title: 'Improvement areas',
            items: feedback.improvementAreas,
            accent: AppColors.accent,
          ),
        ],
        if (feedback.tips.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BulletCard(
            title: 'Actionable tips',
            items: feedback.tips,
            accent: AppColors.brand,
          ),
        ],
      ],
      if (snapshot.evaluation != null &&
          snapshot.evaluation!.id.isNotEmpty) ...[
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pushNamed(
              AppRoutes.deepFeedback,
              arguments: DeepFeedbackArgs(
                submissionId: widget.args.submissionId,
                evaluationId: snapshot.evaluation!.id,
                feedbackId: snapshot.feedback?.id,
                assessmentId:
                    widget.args.assessmentId ?? snapshot.evaluation?.assessmentId,
                title: widget.args.title,
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: const BorderSide(color: AppColors.brand),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Improve answer with AI'),
        ),
      ],
    ];
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({
    required this.scoreLabel,
    this.percentageLabel,
    this.grade,
    this.attemptNumber,
  });

  final String scoreLabel;
  final String? percentageLabel;
  final String? grade;
  final int? attemptNumber;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (attemptNumber != null) 'Attempt $attemptNumber',
      ?percentageLabel,
      if (grade != null && grade!.isNotEmpty) 'Grade $grade',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your score',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scoreLabel,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meta.join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  const _MutedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: child,
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.index,
    required this.score,
  });

  final int index;
  final EvaluationScoreItem score;

  @override
  Widget build(BuildContext context) {
    final criteria = score.rubricBreakdown.entries.toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question $index · ${score.scoreLabel}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (score.feedback != null && score.feedback!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              score.feedback!,
              style: const TextStyle(color: AppColors.ink, height: 1.4),
            ),
          ],
          if (criteria.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final entry in criteria)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OverallFeedbackCard extends StatelessWidget {
  const _OverallFeedbackCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall feedback',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(color: AppColors.ink, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.title,
    required this.items,
    required this.accent,
  });

  final String title;
  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
