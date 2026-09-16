import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// S-45 Submission status — processing / AI evaluating / ready.
class SubmissionStatusScreen extends StatefulWidget {
  const SubmissionStatusScreen({
    super.key,
    required this.args,
    this.testsRepository,
    this.pollInterval = const Duration(seconds: 5),
  });

  final SubmissionStatusArgs args;
  final TestsGateway? testsRepository;
  final Duration pollInterval;

  @override
  State<SubmissionStatusScreen> createState() => _SubmissionStatusScreenState();
}

class _SubmissionStatusScreenState extends State<SubmissionStatusScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  Timer? _poll;
  bool _loading = true;
  String? _error;
  late SubmissionStatusPayload _payload;

  @override
  void initState() {
    super.initState();
    _payload = SubmissionStatusPayload(
      id: widget.args.submissionId,
      status: widget.args.initialStatus ?? 'pending',
    );
    _refresh(initial: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (!_payload.isPending) return;
    _poll = Timer(widget.pollInterval, () => _refresh());
  }

  Future<void> _refresh({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final next = await _tests.getSubmissionStatus(widget.args.submissionId);
      if (!mounted) return;
      setState(() {
        _payload = next;
        _loading = false;
        _error = null;
      });
      _schedulePoll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to refresh submission status.';
      });
      if (_payload.isPending) {
        _schedulePoll();
      }
    }
  }

  void _openResults() {
    Navigator.of(context).pushNamed(
      AppRoutes.resultFeedback,
      arguments: ResultFeedbackArgs(
        submissionId: widget.args.submissionId,
        assessmentId: widget.args.assessmentId,
        title: widget.args.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.title?.trim().isNotEmpty == true
        ? widget.args.title!.trim()
        : 'Submission';
    final stage = SubmissionPipeline.stageFor(_payload.status);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Submission status'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: () => _refresh(initial: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your answers were submitted. We are preparing feedback.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (_loading && widget.args.initialStatus == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    ),
                  )
                else ...[
                  _StatusHero(
                    label: _payload.statusLabel,
                    stage: stage,
                    failureReason: _payload.failureReason,
                  ),
                  const SizedBox(height: 20),
                  _PipelineSteps(stage: stage),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (stage == SubmissionPipelineStage.ready)
                    FilledButton(
                      onPressed: _openResults,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('View result'),
                    )
                  else if (stage == SubmissionPipelineStage.failed)
                    OutlinedButton(
                      onPressed: () => _refresh(initial: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.brandSoft),
                      ),
                      child: const Text('Check again'),
                    )
                  else
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _payload.isPending
                              ? 'Checking for updates…'
                              : 'Waiting…',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back to tests'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.label,
    required this.stage,
    this.failureReason,
  });

  final String label;
  final SubmissionPipelineStage stage;
  final String? failureReason;

  @override
  Widget build(BuildContext context) {
    final colors = switch (stage) {
      SubmissionPipelineStage.ready => (
          const Color(0xFFE6F5EE),
          AppColors.success,
          Icons.check_circle_outline,
        ),
      SubmissionPipelineStage.failed => (
          const Color(0xFFFDECEC),
          AppColors.danger,
          Icons.error_outline,
        ),
      SubmissionPipelineStage.evaluating => (
          AppColors.brandSoft,
          AppColors.brand,
          Icons.auto_awesome_outlined,
        ),
      SubmissionPipelineStage.processing => (
          AppColors.brandSoft,
          AppColors.brand,
          Icons.hourglass_top_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(colors.$3, color: colors.$2, size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.$2,
            ),
          ),
          if (failureReason != null && failureReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              failureReason!,
              style: const TextStyle(color: AppColors.danger, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _PipelineSteps extends StatelessWidget {
  const _PipelineSteps({required this.stage});

  final SubmissionPipelineStage stage;

  @override
  Widget build(BuildContext context) {
    final steps = <(String, bool)>[
      (
        'Processing',
        stage == SubmissionPipelineStage.processing ||
            stage == SubmissionPipelineStage.evaluating ||
            stage == SubmissionPipelineStage.ready,
      ),
      (
        'AI evaluating',
        stage == SubmissionPipelineStage.evaluating ||
            stage == SubmissionPipelineStage.ready,
      ),
      (
        'Ready',
        stage == SubmissionPipelineStage.ready,
      ),
    ];

    if (stage == SubmissionPipelineStage.failed) {
      return const Text(
        'Evaluation could not finish. You can check again or return later.',
        style: TextStyle(color: AppColors.muted, height: 1.4),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepRow(
            label: steps[i].$1,
            done: steps[i].$2,
            active: i == 0
                ? stage == SubmissionPipelineStage.processing
                : i == 1
                    ? stage == SubmissionPipelineStage.evaluating
                    : stage == SubmissionPipelineStage.ready,
          ),
          if (i < steps.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done || active ? AppColors.brand : AppColors.muted,
          size: 22,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: active || done ? FontWeight.w700 : FontWeight.w500,
            color: done || active ? AppColors.ink : AppColors.muted,
          ),
        ),
      ],
    );
  }
}
