import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/ai_answer_upload_models.dart';
import 'package:student_mobile/features/tests/domain/ai_evaluation_hub_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';

/// Bottom-nav AI Evaluation hub — question-wise short/long answers by subject.
class AiEvaluationHubScreen extends StatefulWidget {
  const AiEvaluationHubScreen({
    super.key,
    this.testsRepository,
  });

  final TestsGateway? testsRepository;

  @override
  State<AiEvaluationHubScreen> createState() => _AiEvaluationHubScreenState();
}

enum _KindFilter { all, shortAnswer, longAnswer }

class _AiEvaluationHubScreenState extends State<AiEvaluationHubScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _pageBg = Color(0xFFF8FAFD);

  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  bool _opening = false;
  String? _error;
  String _query = '';
  _KindFilter _kindFilter = _KindFilter.all;
  String? _subjectFilter;
  List<AiEvalQuestionItem> _items = const <AiEvalQuestionItem>[];

  @override
  void initState() {
    super.initState();
    _items = const <AiEvalQuestionItem>[];
    StudentShell.aiEvalTabTicks.addListener(_onTabSelected);
    _load();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Web hot reload can leave State fields undefined after field reshuffles.
    final dynamic raw = _items;
    if (raw is! List<AiEvalQuestionItem>) {
      _items = const <AiEvalQuestionItem>[];
    }
  }

  @override
  void dispose() {
    StudentShell.aiEvalTabTicks.removeListener(_onTabSelected);
    super.dispose();
  }

  void _onTabSelected() {
    if (!mounted || _loading) return;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settled = await Future.wait<Object>([
        _tests.loadPastResults(),
        _tests.loadTests(),
      ]);
      if (!mounted) return;

      final snapshot = settled[0] as PastResultsSnapshot;
      final tests = settled[1] as TestsSnapshot;

      final aiTests = (tests.items)
          .where(_isAiEvaluationTest)
          .toList(growable: false);

      final details = <AssessmentDetailSnapshot>[];
      for (final test in aiTests) {
        try {
          details.add(
            await _tests.loadAssessmentDetail(
              AssessmentDetailArgs(assessmentId: test.id, title: test.title),
            ),
          );
        } catch (_) {
          // Skip assessments the student cannot open.
        }
      }

      final items = <AiEvalQuestionItem>[];
      for (final detail in details) {
        final assessment = detail.assessment;
        final questions = List<AssessmentQuestionPreview>.from(
          assessment.questions,
        ).where(isAiEvaluableQuestion).toList(growable: false);
        if (questions.isEmpty) continue;

        final submission = _latestForAssessment(snapshot, assessment.id);
        final status = resolveAiEvalStatus(submission);

        for (var i = 0; i < questions.length; i++) {
          final question = questions[i];
          items.add(
            AiEvalQuestionItem(
              assessmentId: assessment.id,
              assessmentTitle: assessment.title,
              question: question,
              questionIndex: i,
              questionTotal: questions.length,
              kind: AiEvalQuestionItem.kindFor(question),
              status: status,
              subjectLabel: _subjectLabelFor(question, assessment.title),
              examCategory: assessment.typeLabel,
              submission: submission,
              scoreMax: question.maxMarks,
            ),
          );
        }
      }

      setState(() {
        _items = List<AiEvalQuestionItem>.from(items);
        _loading = false;
        if (_subjectFilter != null &&
            !_items.any((item) => item.subjectLabel == _subjectFilter)) {
          _subjectFilter = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = _safeItems; // keep last known-good list (never null)
        _error = error is ApiException
            ? error.message
            : 'Unable to load AI evaluations.';
      });
    }
  }

  static bool _isAiEvaluationTest(TestListItem item) {
    final title = item.title.toLowerCase();
    if (item.type == TestKind.assignment) return true;
    return title.contains('ai evaluation') ||
        title.contains('essay') ||
        title.contains('subjective') ||
        title.contains('descriptive') ||
        title.contains('short answer');
  }

  static String _subjectFromTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('polity')) return 'Polity';
    if (lower.contains('history')) return 'History';
    if (lower.contains('economy')) return 'Economy';
    if (lower.contains('geography')) return 'Geography';
    if (lower.contains('science')) return 'Science';
    return 'General';
  }

  static String _subjectLabelFor(
    AssessmentQuestionPreview question,
    String assessmentTitle,
  ) {
    final named = question.subjectName?.trim();
    if (named != null && named.isNotEmpty) return named;

    final text = '${question.content ?? ''} $assessmentTitle'.toLowerCase();
    if (text.contains('preamble') ||
        text.contains('constitution') ||
        text.contains('judicial') ||
        text.contains('fundamental right') ||
        text.contains('basic structure')) {
      return 'Polity';
    }
    if (text.contains('mughal') ||
        text.contains('maurya') ||
        text.contains('quit india') ||
        text.contains('history')) {
      return 'History';
    }
    return _subjectFromTitle(assessmentTitle);
  }

  SubmissionSummary? _latestForAssessment(
    PastResultsSnapshot snapshot,
    String assessmentId,
  ) {
    SubmissionSummary? best;
    for (final item in snapshot.submissions) {
      if (item.assessmentId != assessmentId) continue;
      if (best == null) {
        best = item;
        continue;
      }
      final bestStamp = best.evaluatedAt ?? best.submittedAt ?? best.updatedAt;
      final itemStamp = item.evaluatedAt ?? item.submittedAt ?? item.updatedAt;
      if (bestStamp == null) {
        best = item;
      } else if (itemStamp != null && itemStamp.isAfter(bestStamp)) {
        best = item;
      }
    }
    return best;
  }

  List<AiEvalQuestionItem> get _safeItems {
    try {
      final dynamic raw = _items;
      if (raw == null) return const <AiEvalQuestionItem>[];
      if (raw is! List) return const <AiEvalQuestionItem>[];
      return List<AiEvalQuestionItem>.from(
        raw.whereType<AiEvalQuestionItem>(),
      );
    } catch (_) {
      return const <AiEvalQuestionItem>[];
    }
  }

  List<AiEvalQuestionItem> get _visibleItems {
    try {
      final query = _query.trim().toLowerCase();
      final items = _safeItems;
      if (items.isEmpty) return const <AiEvalQuestionItem>[];
      return items.where((item) {
        if (_kindFilter == _KindFilter.shortAnswer &&
            item.kind != AiAnswerKind.shortAnswer) {
          return false;
        }
        if (_kindFilter == _KindFilter.longAnswer &&
            item.kind != AiAnswerKind.longAnswer) {
          return false;
        }
        if (_subjectFilter != null && item.subjectLabel != _subjectFilter) {
          return false;
        }
        if (query.isEmpty) return true;
        return item.questionText.toLowerCase().contains(query) ||
            item.subjectLabel.toLowerCase().contains(query) ||
            item.assessmentTitle.toLowerCase().contains(query) ||
            item.kindLabel.toLowerCase().contains(query);
      }).toList(growable: false);
    } catch (_) {
      return const <AiEvalQuestionItem>[];
    }
  }

  List<String> get _subjects {
    try {
      final items = _safeItems;
      if (items.isEmpty) return const [];
      final values = items.map((item) => item.subjectLabel).toSet().toList()
        ..sort();
      return values;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openQuestion(
    AiEvalQuestionItem item, {
    bool forceReattempt = false,
  }) async {
    if (_opening) return;

    if (!forceReattempt &&
        item.status == AiEvalQuestionStatus.evaluated &&
        item.submission != null) {
      await Navigator.of(context).pushNamed(
        AppRoutes.resultFeedback,
        arguments: ResultFeedbackArgs(
          submissionId: item.submission!.id,
          assessmentId: item.assessmentId,
          title: item.assessmentTitle,
          initialScoreIndex: item.questionIndex,
        ),
      );
      if (mounted) await _load();
      return;
    }

    if (!forceReattempt &&
        item.status == AiEvalQuestionStatus.evaluating &&
        item.submission != null) {
      await Navigator.of(context).pushNamed(
        AppRoutes.submissionStatus,
        arguments: SubmissionStatusArgs(
          submissionId: item.submission!.id,
          assessmentId: item.assessmentId,
          title: item.assessmentTitle,
          initialStatus: item.submission!.status,
          includesMedia: true,
        ),
      );
      if (mounted) await _load();
      return;
    }

    await _beginUpload(item, forceNewAttempt: forceReattempt);
  }

  Future<void> _beginUpload(
    AiEvalQuestionItem item, {
    required bool forceNewAttempt,
  }) async {
    setState(() => _opening = true);
    try {
      AssessmentAttemptSession session;
      final existing = item.submission;
      if (!forceNewAttempt &&
          existing != null &&
          existing.isDraft &&
          (existing.assessmentAttemptId ?? '').isNotEmpty) {
        session = AssessmentAttemptSession(
          attempt: AssessmentAttemptSummary(
            id: existing.assessmentAttemptId!,
            assessmentId: item.assessmentId,
            attemptNumber: existing.attemptNumber,
            status: AttemptLifecycle.inProgress,
          ),
          submission: existing,
        );
      } else {
        session = await _tests.startAttempt(item.assessmentId);
      }

      if (!mounted) return;
      final result = await Navigator.of(context).pushNamed(
        AppRoutes.aiAnswerUpload,
        arguments: AiAnswerUploadArgs(
          submissionId: session.submission.id,
          assessmentId: item.assessmentId,
          question: item.question,
          questionIndex: item.questionIndex,
          questionTotal: item.questionTotal,
          assessmentTitle: item.assessmentTitle,
          tags: [
            item.kindLabel,
            item.subjectLabel,
            item.examCategory,
          ],
          finalizeOnSubmit: item.questionTotal <= 1,
        ),
      );

      if (!mounted) return;

      if (result is AiAnswerUploadResult && result.finalized) {
        await Navigator.of(context).pushNamed(
          AppRoutes.submissionStatus,
          arguments: SubmissionStatusArgs(
            submissionId: session.submission.id,
            assessmentId: item.assessmentId,
            title: item.assessmentTitle,
            initialStatus: result.submissionStatus ?? 'ready_for_evaluation',
            includesMedia: true,
          ),
        );
      } else if (result is AiAnswerUploadResult &&
          result.images.isNotEmpty &&
          item.questionTotal > 1) {
        final shouldSubmit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Answer saved'),
            content: const Text(
              'Your page was saved. Submit this attempt for AI evaluation now, '
              'or keep answering other questions.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep answering'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit for AI'),
              ),
            ],
          ),
        );
        if (shouldSubmit == true && mounted) {
          final summary =
              await _tests.finalizeSubmission(session.submission.id);
          if (!mounted) return;
          await Navigator.of(context).pushNamed(
            AppRoutes.submissionStatus,
            arguments: SubmissionStatusArgs(
              submissionId: session.submission.id,
              assessmentId: item.assessmentId,
              title: item.assessmentTitle,
              initialStatus: summary.status,
              includesMedia: true,
            ),
          );
        }
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to open answer upload.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    final subjects = _subjects;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PragyuLogo(
                            height: PragyuLogo.headerHeight,
                            semanticsLabel: 'Pragyu',
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Upload · AI score · Improve',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Alerts',
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.alerts),
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: _ink,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      onPressed: () => StudentShell.of(context)?.goToTab(4),
                      icon: const Icon(
                        Icons.person_outline_rounded,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading && _safeItems.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: _blue),
                      )
                    : RefreshIndicator(
                        color: _blue,
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          children: [
                            const Text(
                              'AI Evaluation',
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pick a question, upload your sheet, then review AI score and improvements.\n'
                              'Short answer = concise written · Long answer = essay / descriptive.',
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                height: 1.4,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const _HowItWorks(),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search by question, subject…',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE6EAF2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE6EAF2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'All',
                                    selected: _kindFilter == _KindFilter.all,
                                    onTap: () => setState(
                                      () => _kindFilter = _KindFilter.all,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Short answer',
                                    selected:
                                        _kindFilter == _KindFilter.shortAnswer,
                                    onTap: () => setState(
                                      () =>
                                          _kindFilter = _KindFilter.shortAnswer,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Long answer',
                                    selected:
                                        _kindFilter == _KindFilter.longAnswer,
                                    onTap: () => setState(
                                      () =>
                                          _kindFilter = _KindFilter.longAnswer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_kindFilter != _KindFilter.all) ...[
                              const SizedBox(height: 8),
                              Text(
                                _kindFilter == _KindFilter.shortAnswer
                                    ? 'Showing concise written questions only.'
                                    : 'Showing essay / descriptive questions only.',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  color: _muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (subjects.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _FilterChip(
                                      label: 'All subjects',
                                      selected: _subjectFilter == null,
                                      onTap: () => setState(
                                        () => _subjectFilter = null,
                                      ),
                                    ),
                                    for (final subject in subjects) ...[
                                      const SizedBox(width: 8),
                                      _FilterChip(
                                        label: subject,
                                        selected: _subjectFilter == subject,
                                        onTap: () => setState(
                                          () => _subjectFilter = subject,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFC0392B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (_opening)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(color: _blue),
                              ),
                            if (visible.isEmpty)
                              _EmptyState(
                                hasItems: _safeItems.isNotEmpty,
                                onPractice: () =>
                                    StudentShell.of(context)?.goToTab(2),
                                onClearFilters: _safeItems.isNotEmpty
                                    ? () => setState(() {
                                          _kindFilter = _KindFilter.all;
                                          _subjectFilter = null;
                                          _query = '';
                                        })
                                    : null,
                              )
                            else ...[
                              Text(
                                '${visible.length} question${visible.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final item in visible)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _QuestionCard(
                                    item: item,
                                    onOpen: () => _openQuestion(item),
                                    onReattempt: item.canReattempt
                                        ? () => _openQuestion(
                                              item,
                                              forceReattempt: true,
                                            )
                                        : null,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = <(String, String, IconData)>[
      ('1', 'Upload', Icons.photo_camera_outlined),
      ('2', 'AI scores', Icons.auto_awesome_outlined),
      ('3', 'Improve', Icons.trending_up_rounded),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              const Expanded(
                child: Divider(color: Color(0xFFE6EAF2), thickness: 1),
              ),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F1FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(steps[i].$3, color: Color(0xFF2F7BFF), size: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2B4C),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      color: selected ? const Color(0xFFE8F1FF) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2F7BFF)
                  : const Color(0xFFE6EAF2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: selected
                  ? const Color(0xFF2F7BFF)
                  : const Color(0xFF7A8499),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.item,
    required this.onOpen,
    this.onReattempt,
  });

  final AiEvalQuestionItem item;
  final VoidCallback onOpen;
  final VoidCallback? onReattempt;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      AiEvalQuestionStatus.evaluated => const Color(0xFF22A06B),
      AiEvalQuestionStatus.evaluating => const Color(0xFF2F7BFF),
      AiEvalQuestionStatus.failed => const Color(0xFFC0392B),
      AiEvalQuestionStatus.draft => const Color(0xFFC47A1A),
      AiEvalQuestionStatus.notStarted => const Color(0xFF7A8499),
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniChip(
                    label: item.kindLabel,
                    color: item.kind == AiAnswerKind.shortAnswer
                        ? const Color(0xFF7B5CFF)
                        : const Color(0xFF2F7BFF),
                  ),
                  _MiniChip(
                    label: item.subjectLabel,
                    color: const Color(0xFF1A2B4C),
                  ),
                  _MiniChip(
                    label: item.examCategory,
                    color: const Color(0xFF7A8499),
                  ),
                  if (item.question.maxMarks != null)
                    _MiniChip(
                      label: item.question.maxMarks ==
                              item.question.maxMarks!.roundToDouble()
                          ? '${item.question.maxMarks!.round()} Marks'
                          : '${item.question.maxMarks} Marks',
                      color: const Color(0xFFC47A1A),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.kindHint,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: Color(0xFF7A8499),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Q${item.questionIndex + 1}. ${item.questionText}',
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF1A2B4C),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.assessmentTitle,
                softWrap: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: Color(0xFF7A8499),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.status == AiEvalQuestionStatus.evaluated &&
                              item.scoreLabel.isNotEmpty
                          ? 'Score ${item.scoreLabel}'
                          : item.statusLabel,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2F7BFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        item.primaryActionLabel,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (onReattempt != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReattempt,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2F7BFF),
                          side: const BorderSide(color: Color(0xFF2F7BFF)),
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          item.status == AiEvalQuestionStatus.failed
                              ? 'Retry upload'
                              : 'Reattempt',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasItems,
    required this.onPractice,
    this.onClearFilters,
  });

  final bool hasItems;
  final VoidCallback onPractice;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final title = hasItems
        ? 'No questions match these filters'
        : 'No AI evaluation questions yet';
    final body = hasItems
        ? 'Try All, clear the subject filter, or search with a different keyword.'
        : 'When your academy assigns short or long answer tests, they show up here for upload and AI scoring.';

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Icon(
            hasItems ? Icons.filter_alt_off_outlined : Icons.auto_awesome_outlined,
            size: 40,
            color: const Color(0xFF2F7BFF),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Color(0xFF7A8499),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (onClearFilters != null)
            FilledButton(
              onPressed: onClearFilters,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2F7BFF),
              ),
              child: const Text('Clear filters'),
            )
          else
            TextButton.icon(
              onPressed: onPractice,
              icon: const Icon(Icons.track_changes_rounded),
              label: const Text('Go to Practice'),
            ),
          if (onClearFilters != null)
            TextButton.icon(
              onPressed: onPractice,
              icon: const Icon(Icons.track_changes_rounded),
              label: const Text('Go to Practice'),
            ),
        ],
      ),
    );
  }
}
