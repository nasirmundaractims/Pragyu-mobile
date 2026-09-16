import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// S-41 Assessment detail — overview, results, entry to S-42 instructions.
class AssessmentDetailScreen extends StatefulWidget {
  const AssessmentDetailScreen({
    super.key,
    required this.args,
    this.testsRepository,
  });

  final AssessmentDetailArgs args;
  final TestsGateway? testsRepository;

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  bool _actionBusy = false;
  String? _error;
  AssessmentDetailSnapshot? _snapshot;

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
      final snapshot = await _tests.loadAssessmentDetail(widget.args);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Unable to load this test. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openInstructions({bool continueSession = false}) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.attemptInstructions,
      arguments: AttemptInstructionsArgs(
        assessmentId: snapshot.assessment.id,
        title: snapshot.assessment.title,
        attemptId: continueSession ? snapshot.activeAttempt?.id : null,
        submissionId: continueSession ? snapshot.activeSubmission?.id : null,
      ),
    );
  }

  Future<void> _submit() async {
    final snapshot = _snapshot;
    final submissionId = snapshot?.activeSubmission?.id;
    if (snapshot == null || submissionId == null || _actionBusy) return;

    setState(() => _actionBusy = true);
    try {
      final summary = await _tests.finalizeSubmission(submissionId);
      if (!mounted) return;
      setState(() => _actionBusy = false);
      await Navigator.of(context).pushNamed(
        AppRoutes.submissionStatus,
        arguments: SubmissionStatusArgs(
          submissionId: submissionId,
          assessmentId: snapshot.assessment.id,
          title: snapshot.assessment.title,
          initialStatus: summary.status,
        ),
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to submit this attempt.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.assessment.title ??
        (widget.args.title?.trim().isNotEmpty == true
            ? widget.args.title!.trim()
            : 'Assessment');

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
    final assessment = snapshot.assessment;
    final dueLabel = assessment.due?.label;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          assessment.metaLine,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        if (dueLabel != null && dueLabel.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _DueChip(
              label: dueLabel,
              urgency: assessment.due?.urgency ?? DueUrgency.none,
            ),
          ),
        ],
        if (assessment.description != null) ...[
          const SizedBox(height: 18),
          const Text(
            'About',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            assessment.description!,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
        if (assessment.instructions != null) ...[
          const SizedBox(height: 18),
          const Text(
            'Instructions',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            assessment.instructions!,
            style: const TextStyle(
              color: AppColors.ink,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
        if (snapshot.finalResult != null) ...[
          const SizedBox(height: 20),
          _ResultsCard(result: snapshot.finalResult!),
        ],
        if (snapshot.canContinue) ...[
          const SizedBox(height: 20),
          _SessionCard(
            attempt: snapshot.activeAttempt!,
            submission: snapshot.activeSubmission!,
          ),
        ],
        const SizedBox(height: 20),
        if (snapshot.studentProfileId == null)
          const Text(
            'Student profile is required before you can start this test.',
            style: TextStyle(color: AppColors.danger, height: 1.45),
          )
        else if (snapshot.canStart)
          FilledButton(
            onPressed: () => _openInstructions(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Start attempt'),
          )
        else if (snapshot.canContinue) ...[
          FilledButton(
            onPressed: () => _openInstructions(continueSession: true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Continue attempt'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _actionBusy ? null : _submit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.brandSoft),
            ),
            child: Text(_actionBusy ? 'Submitting…' : 'Submit attempt'),
          ),
        ],
        if (assessment.questions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Question preview (${assessment.questions.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Full answering opens after you accept instructions (S-42 → S-43).',
            style: TextStyle(
              color: AppColors.muted,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ...assessment.questions.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final question = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuestionTile(index: index, question: question),
            );
          }),
        ],
      ],
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({
    required this.label,
    required this.urgency,
  });

  final String label;
  final DueUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final urgent = urgency == DueUrgency.overdue ||
        urgency == DueUrgency.endsSoon ||
        urgency == DueUrgency.dueToday;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFDECEC) : const Color(0xFFE6F5EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: urgent ? AppColors.danger : AppColors.success,
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.result});

  final FinalResultSummary result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your result',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${result.marksLabel} marks',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
          if (result.rank != null || result.percentile != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (result.rank != null) 'Rank ${result.rank}',
                if (result.percentile != null)
                  'Percentile ${result.percentile!.toStringAsFixed(0)}',
              ].join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.attempt,
    required this.submission,
  });

  final AssessmentAttemptSummary attempt;
  final SubmissionSummary submission;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open attempt',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Attempt #${attempt.attemptNumber} · ${attempt.statusLabel}',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          Text(
            'Submission · ${submission.statusLabel}',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.index,
    required this.question,
  });

  final int index;
  final AssessmentQuestionPreview question;

  @override
  Widget build(BuildContext context) {
    final content = question.content ?? 'Question $index';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
                if (question.maxMarks != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${question.maxMarks == question.maxMarks!.roundToDouble() ? question.maxMarks!.round() : question.maxMarks} marks',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
