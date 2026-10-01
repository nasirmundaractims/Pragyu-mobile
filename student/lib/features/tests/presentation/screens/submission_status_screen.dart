import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/student_hub_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// S-45 Submission status — processing / queued / evaluating / ready / failed.
///
/// Honesty rules (slice 0.2):
/// - Distinct queued vs evaluating copy
/// - Surface `failure_reason` when present
/// - After [stuckAfter], stop the endless spinner and explain next steps
class SubmissionStatusScreen extends StatefulWidget {
  const SubmissionStatusScreen({
    super.key,
    required this.args,
    this.testsRepository,
    this.pollInterval = const Duration(seconds: 5),
    this.stuckAfter = const Duration(seconds: 45),
  });

  final SubmissionStatusArgs args;
  final TestsGateway? testsRepository;
  final Duration pollInterval;

  /// How long the same pending status may spin before we show a delayed UI.
  final Duration stuckAfter;

  @override
  State<SubmissionStatusScreen> createState() => _SubmissionStatusScreenState();
}

class _SubmissionStatusScreenState extends State<SubmissionStatusScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  Timer? _poll;
  Timer? _stuckTimer;
  bool _loading = true;
  bool _takingLonger = false;
  String? _error;
  String? _trackedStatus;
  late SubmissionStatusPayload _payload;

  @override
  void initState() {
    super.initState();
    _payload = SubmissionStatusPayload(
      id: widget.args.submissionId,
      status: widget.args.initialStatus ?? 'pending',
    );
    _trackStatus(_payload.status);
    _refresh(initial: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _stuckTimer?.cancel();
    super.dispose();
  }

  void _trackStatus(String status) {
    if (_trackedStatus == status) return;
    _trackedStatus = status;
    _stuckTimer?.cancel();
    _takingLonger = false;
    if (!SubmissionPipeline.isPending(status)) return;
    _stuckTimer = Timer(widget.stuckAfter, () {
      if (!mounted) return;
      if (!_payload.isPending) return;
      if (_payload.status != status) return;
      setState(() => _takingLonger = true);
    });
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
        _trackStatus(next.status);
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

  bool get _needsHonestWaitUi {
    if (!_payload.isPending) return false;
    return _payload.isBlocked || _takingLonger;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.title?.trim().isNotEmpty == true
        ? widget.args.title!.trim()
        : 'Submission';
    final stage = SubmissionPipeline.stageFor(_payload.status);
    final phaseTitle = _payload.phaseTitle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: StudentHubColors.pageBg,
        appBar: AppBar(
          backgroundColor: StudentHubColors.pageBg,
          title: const Text('Submission status'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: StudentHubColors.blue,
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
                    color: StudentHubColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle(
                    stage: stage,
                    includesMedia: widget.args.includesMedia,
                    isOcr: _payload.isOcrStage,
                    failureReason: _payload.failureReason,
                    takingLonger: _takingLonger,
                  ),
                  style: const TextStyle(
                    color: StudentHubColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading && widget.args.initialStatus == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: StudentHubColors.blue,
                      ),
                    ),
                  )
                else ...[
                  _StatusHero(
                    label: phaseTitle,
                    stage: stage,
                    failureReason: _payload.failureReason,
                    takingLonger: _takingLonger,
                    blocked: _payload.isBlocked,
                  ),
                  const SizedBox(height: 20),
                  _PipelineSteps(
                    stage: stage,
                    includesMedia: widget.args.includesMedia ||
                        _payload.isOcrStage,
                    blocked: _payload.isBlocked || _takingLonger,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: StudentHubColors.danger,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (stage == SubmissionPipelineStage.ready)
                    FilledButton(
                      onPressed: _openResults,
                      style: FilledButton.styleFrom(
                        backgroundColor: StudentHubColors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('View result'),
                    )
                  else if (stage == SubmissionPipelineStage.failed)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => _refresh(initial: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: StudentHubColors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Try again'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _failedNextSteps(_payload.failureReason),
                          style: const TextStyle(
                            color: StudentHubColors.muted,
                            height: 1.45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  else if (_needsHonestWaitUi)
                    _HonestWaitPanel(
                      failureReason: _payload.failureReason,
                      takingLonger: _takingLonger,
                      stage: stage,
                      onRetry: () => _refresh(initial: true),
                    )
                  else
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: StudentHubColors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            stage == SubmissionPipelineStage.queued
                                ? 'In the AI queue — checking automatically…'
                                : stage == SubmissionPipelineStage.evaluating
                                    ? 'AI is scoring — checking automatically…'
                                    : 'Processing — checking automatically…',
                            softWrap: true,
                            style: const TextStyle(
                              color: StudentHubColors.muted,
                            ),
                          ),
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

  static String _failedNextSteps(String? failureReason) {
    final hasReason =
        failureReason != null && failureReason.trim().isNotEmpty;
    if (hasReason) {
      return 'If this keeps failing, contact your institute with the message above.';
    }
    return 'Pull to refresh later, or contact your institute if it does not clear.';
  }

  static String _subtitle({
    required SubmissionPipelineStage stage,
    required bool includesMedia,
    required bool isOcr,
    String? failureReason,
    required bool takingLonger,
  }) {
    if (stage == SubmissionPipelineStage.ready) {
      return 'Your AI evaluation is ready. Open the result to review scores and feedback.';
    }
    if (stage == SubmissionPipelineStage.failed) {
      return 'We could not finish evaluating this attempt. You can try checking again.';
    }
    if (failureReason != null && failureReason.trim().isNotEmpty) {
      return 'Evaluation could not start yet. See the reason below, then pull to refresh or contact your institute.';
    }
    if (takingLonger) {
      switch (stage) {
        case SubmissionPipelineStage.queued:
          return 'Still waiting in the AI queue longer than usual. You can leave and come back — we will keep working in the background.';
        case SubmissionPipelineStage.evaluating:
          return 'AI evaluation is taking longer than usual. You can leave this screen; we will notify you when it finishes.';
        case SubmissionPipelineStage.processing:
          return 'Processing is taking longer than usual. Pull to refresh, or return later.';
        case SubmissionPipelineStage.ready:
        case SubmissionPipelineStage.failed:
          break;
      }
    }
    if (includesMedia || isOcr) {
      if (stage == SubmissionPipelineStage.processing) {
        return 'Your handwritten pages are being read with OCR before AI scoring.';
      }
      if (stage == SubmissionPipelineStage.queued) {
        return 'OCR finished. Your answer is queued for AI evaluation.';
      }
      if (stage == SubmissionPipelineStage.evaluating) {
        return 'AI evaluation is processing. You will be notified when it completes.';
      }
    }
    switch (stage) {
      case SubmissionPipelineStage.queued:
        return 'Your answer is in the AI queue. Scoring starts automatically when a worker is available.';
      case SubmissionPipelineStage.evaluating:
        return 'AI is scoring your answers now. This usually finishes within a few minutes.';
      case SubmissionPipelineStage.processing:
        return 'Your answer was submitted successfully. Evaluation will start shortly.';
      case SubmissionPipelineStage.ready:
      case SubmissionPipelineStage.failed:
        break;
    }
    return 'Your answer was submitted successfully.';
  }
}

class _HonestWaitPanel extends StatelessWidget {
  const _HonestWaitPanel({
    required this.failureReason,
    required this.takingLonger,
    required this.stage,
    required this.onRetry,
  });

  final String? failureReason;
  final bool takingLonger;
  final SubmissionPipelineStage stage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasReason =
        failureReason != null && failureReason!.trim().isNotEmpty;
    final headline = hasReason
        ? 'Evaluation paused'
        : 'Taking longer than usual';
    final body = hasReason
        ? 'Pull to refresh after the issue is fixed, or contact your institute.'
        : (stage == SubmissionPipelineStage.queued
            ? 'Still queued. Leave and open AI Eval later, or check again now.'
            : 'Still working. Leave this screen — check AI Eval or pull to refresh later.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: const Color(0xFFF0D9A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFB7791F),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: StudentHubColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: StudentHubColors.muted,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                    if (hasReason) ...[
                      const SizedBox(height: 8),
                      Text(
                        failureReason!.trim(),
                        style: const TextStyle(
                          color: StudentHubColors.danger,
                          height: 1.4,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: StudentHubColors.ink,
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: StudentHubColors.border),
            ),
            child: Text(takingLonger && !hasReason ? 'Check again' : 'Try again'),
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.label,
    required this.stage,
    this.failureReason,
    this.takingLonger = false,
    this.blocked = false,
  });

  final String label;
  final SubmissionPipelineStage stage;
  final String? failureReason;
  final bool takingLonger;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final warn = blocked || takingLonger;
    final colors = switch (stage) {
      SubmissionPipelineStage.ready => (
          const Color(0xFFE6F5EE),
          StudentHubColors.success,
          Icons.check_circle_outline,
        ),
      SubmissionPipelineStage.failed => (
          const Color(0xFFFDECEC),
          StudentHubColors.danger,
          Icons.error_outline,
        ),
      _ when warn => (
          const Color(0xFFFFF8E8),
          const Color(0xFFB7791F),
          Icons.schedule_rounded,
        ),
      SubmissionPipelineStage.queued => (
          StudentHubColors.blueSoft,
          StudentHubColors.blue,
          Icons.hourglass_bottom_rounded,
        ),
      SubmissionPipelineStage.evaluating => (
          StudentHubColors.blueSoft,
          StudentHubColors.blue,
          Icons.auto_awesome_outlined,
        ),
      SubmissionPipelineStage.processing => (
          StudentHubColors.blueSoft,
          StudentHubColors.blue,
          Icons.hourglass_top_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: StudentHubColors.border),
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
              style: const TextStyle(
                color: StudentHubColors.danger,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PipelineSteps extends StatelessWidget {
  const _PipelineSteps({
    required this.stage,
    this.includesMedia = false,
    this.blocked = false,
  });

  final SubmissionPipelineStage stage;
  final bool includesMedia;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    if (stage == SubmissionPipelineStage.failed) {
      return const Text(
        'Evaluation could not finish. Try again, or return later.',
        style: TextStyle(color: StudentHubColors.muted, height: 1.4),
      );
    }

    final steps = includesMedia
        ? <(String, bool, bool)>[
            (
              'Submitted',
              true,
              false,
            ),
            (
              'OCR reading pages',
              stage != SubmissionPipelineStage.processing,
              stage == SubmissionPipelineStage.processing,
            ),
            (
              'Queued for AI',
              stage == SubmissionPipelineStage.evaluating ||
                  stage == SubmissionPipelineStage.ready,
              stage == SubmissionPipelineStage.queued,
            ),
            (
              'AI evaluating',
              stage == SubmissionPipelineStage.ready,
              stage == SubmissionPipelineStage.evaluating,
            ),
            (
              'Ready',
              stage == SubmissionPipelineStage.ready,
              false,
            ),
          ]
        : <(String, bool, bool)>[
            (
              'Submitted',
              stage != SubmissionPipelineStage.processing,
              stage == SubmissionPipelineStage.processing,
            ),
            (
              'Queued for AI',
              stage == SubmissionPipelineStage.evaluating ||
                  stage == SubmissionPipelineStage.ready,
              stage == SubmissionPipelineStage.queued,
            ),
            (
              'AI evaluating',
              stage == SubmissionPipelineStage.ready,
              stage == SubmissionPipelineStage.evaluating,
            ),
            (
              'Ready',
              stage == SubmissionPipelineStage.ready,
              false,
            ),
          ];

    // Mark "done" for earlier steps when further along.
    final normalized = <(String, bool, bool)>[];
    for (var i = 0; i < steps.length; i++) {
      final label = steps[i].$1;
      var done = steps[i].$2;
      final active = steps[i].$3;
      // Any later active/ready implies earlier steps done.
      if (!done) {
        for (var j = i + 1; j < steps.length; j++) {
          if (steps[j].$2 || steps[j].$3) {
            done = true;
            break;
          }
        }
      }
      if (stage == SubmissionPipelineStage.ready && i < steps.length - 1) {
        done = true;
      }
      if (stage == SubmissionPipelineStage.processing && i == 0 && !includesMedia) {
        // first step active/done handling already set
      }
      if (includesMedia && i == 0) {
        done = true;
      }
      if (includesMedia &&
          i == 1 &&
          (stage == SubmissionPipelineStage.queued ||
              stage == SubmissionPipelineStage.evaluating ||
              stage == SubmissionPipelineStage.ready)) {
        done = true;
      }
      normalized.add((label, done, active));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < normalized.length; i++) ...[
          _StepRow(
            label: normalized[i].$1,
            done: normalized[i].$2 && !normalized[i].$3,
            active: normalized[i].$3,
            delayed: blocked && normalized[i].$3,
          ),
          if (i < normalized.length - 1) const SizedBox(height: 8),
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
    this.delayed = false,
  });

  final String label;
  final bool done;
  final bool active;
  final bool delayed;

  @override
  Widget build(BuildContext context) {
    final color = delayed
        ? const Color(0xFFB7791F)
        : (done || active ? StudentHubColors.blue : StudentHubColors.muted);
    return Row(
      children: [
        Icon(
          done
              ? Icons.check_circle
              : (delayed
                  ? Icons.schedule_rounded
                  : Icons.radio_button_unchecked),
          color: color,
          size: 22,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: active || done ? FontWeight.w700 : FontWeight.w500,
            color: done || active || delayed
                ? StudentHubColors.ink
                : StudentHubColors.muted,
          ),
        ),
      ],
    );
  }
}
