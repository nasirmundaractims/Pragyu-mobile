import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';

/// S-42 Attempt instructions — timer / rules accept before the CBT player.
class AttemptInstructionsScreen extends StatefulWidget {
  const AttemptInstructionsScreen({
    super.key,
    required this.args,
    this.testsRepository,
  });

  final AttemptInstructionsArgs args;
  final TestsGateway? testsRepository;

  @override
  State<AttemptInstructionsScreen> createState() =>
      _AttemptInstructionsScreenState();
}

class _AttemptInstructionsScreenState extends State<AttemptInstructionsScreen> {
  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  bool _starting = false;
  bool _acked = false;
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
      final snapshot = await _tests.loadAssessmentDetail(
        AssessmentDetailArgs(
          assessmentId: widget.args.assessmentId,
          title: widget.args.title,
        ),
      );
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
            : 'Unable to load instructions. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _startTest() async {
    final snapshot = _snapshot;
    if (snapshot == null || !_acked || _starting) return;

    if (snapshot.studentProfileId == null ||
        snapshot.studentProfileId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student profile is required to start this test.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _starting = true);
    try {
      String attemptId = widget.args.attemptId?.trim() ?? '';
      String submissionId = widget.args.submissionId?.trim() ?? '';

      if (attemptId.isEmpty || submissionId.isEmpty) {
        final open = snapshot.activeAttempt;
        final draft = snapshot.activeSubmission;
        if (open != null &&
            open.isActive &&
            draft != null &&
            draft.isDraft) {
          attemptId = open.id;
          submissionId = draft.id;
        } else {
          final session =
              await _tests.startAttempt(snapshot.assessment.id);
          attemptId = session.attempt.id;
          submissionId = session.submission.id;
        }
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.attemptPlayer,
        arguments: AttemptPlayerArgs(
          assessmentId: snapshot.assessment.id,
          attemptId: attemptId,
          submissionId: submissionId,
          title: snapshot.assessment.title,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to start this test.',
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
            : 'Instructions');

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

    final assessment = _snapshot!.assessment;
    final questionCount =
        assessment.questionsCount ?? assessment.questions.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'Computer Based Test',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          assessment.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          assessment.metaLine,
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Duration',
                value: assessment.durationMinutes != null &&
                        assessment.durationMinutes! > 0
                    ? '${assessment.durationMinutes} min'
                    : '—',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Total marks',
                value: assessment.totalMarks != null
                    ? _formatMarks(assessment.totalMarks!)
                    : '—',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Questions',
                value: questionCount > 0 ? '$questionCount' : '—',
              ),
            ),
          ],
        ),
        if (assessment.description != null) ...[
          const SizedBox(height: 18),
          _Panel(
            child: Text(
              assessment.description!,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.45,
                fontSize: 14,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exam instructions',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              if (assessment.instructions != null)
                Text(
                  assessment.instructions!,
                  style: const TextStyle(
                    color: AppColors.ink,
                    height: 1.5,
                    fontSize: 14,
                  ),
                )
              else
                const _DefaultInstructions(),
              const SizedBox(height: 12),
              const Text(
                'Marking scheme and negative marks (if any) follow the assessment configuration set by your academy.',
                style: TextStyle(
                  color: AppColors.muted,
                  height: 1.4,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _starting
                ? null
                : () => setState(() => _acked = !_acked),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.brandSoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acked,
                    onChanged: _starting
                        ? null
                        : (value) =>
                            setState(() => _acked = value ?? false),
                    activeColor: AppColors.brand,
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'I have read and understood all instructions.',
                        style: TextStyle(
                          color: AppColors.ink,
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_snapshot!.studentProfileId == null) ...[
          const SizedBox(height: 14),
          const Text(
            'Student profile is required before you can start this test.',
            style: TextStyle(color: AppColors.danger, height: 1.45),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _starting
                    ? null
                    : () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.brandSoft),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: !_acked ||
                        _starting ||
                        _snapshot!.studentProfileId == null
                    ? null
                    : _startTest,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _starting ? 'Starting…' : 'Start test',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatMarks(double marks) {
    if (marks == marks.roundToDouble()) return marks.round().toString();
    return marks.toString();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _DefaultInstructions extends StatelessWidget {
  const _DefaultInstructions();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.muted,
      height: 1.45,
      fontSize: 14,
    );
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• One question is shown at a time. Use Previous / Next or the question palette.',
          style: style,
        ),
        SizedBox(height: 6),
        Text(
          '• Answers autosave while you work. Use Mark for Review to revisit later.',
          style: style,
        ),
        SizedBox(height: 6),
        Text(
          '• Submit only when you are finished — you may be redirected to results.',
          style: style,
        ),
        SizedBox(height: 6),
        Text(
          '• Do not leave the exam mid-way unless instructed.',
          style: style,
        ),
      ],
    );
  }
}
