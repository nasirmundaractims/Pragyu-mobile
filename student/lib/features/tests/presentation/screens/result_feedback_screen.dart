import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/share/pragyu_share.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/ai_credit_costs.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';

/// S-46 Result / feedback — redesigned as Pragyu AI Evaluation.
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

enum _MainTab { yourAnswer, aiEvaluation, modelAnswer, comparative }

enum _DetailTab { detailed, suggested }

class _ResultFeedbackScreenState extends State<ResultFeedbackScreen> {
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _pageBg = Color(0xFFF8FAFD);
  static const _purple = Color(0xFF7B5CFF);
  static const _purpleSoft = Color(0xFFF3E9FF);

  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  String? _error;
  ResultFeedbackSnapshot? _snapshot;
  _MainTab _mainTab = _MainTab.aiEvaluation;
  _DetailTab _detailTab = _DetailTab.detailed;
  int _scoreIndex = 0;

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
        final maxIndex =
            snapshot.scores.isEmpty ? 0 : snapshot.scores.length - 1;
        _scoreIndex = widget.args.initialScoreIndex.clamp(0, maxIndex);
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

  String get _title {
    final fromArgs = widget.args.title?.trim();
    if (fromArgs != null && fromArgs.isNotEmpty) return fromArgs;
    return 'AI Evaluation';
  }

  String? get _originalAnswer {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    return extractOriginalAnswerText(snapshot.submission.metadata);
  }

  List<AnswerImageAttachment> get _answerImages {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    return extractAnswerImages(snapshot.submission.metadata);
  }

  Future<void> _shareSummary() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final assessmentId = snapshot.submission.assessmentId;
    final buffer = StringBuffer()
      ..writeln(_title)
      ..writeln('Score: ${snapshot.scoreLabel}');
    if (snapshot.percentageLabel != null) {
      buffer.writeln('Percentage: ${snapshot.percentageLabel}');
    }
    if (snapshot.evaluation?.grade != null) {
      buffer.writeln('Grade: ${snapshot.evaluation!.grade}');
    }
    if ((snapshot.feedback?.summary ?? '').trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(snapshot.feedback!.summary!.trim());
    }
    final detail = buffer.toString().trim();
    if (!mounted) return;
    await PragyuShare.share(
      title: 'AI Evaluation · $_title',
      detail: detail,
      url: assessmentId.trim().isEmpty
          ? null
          : PragyuShare.assessmentUrl(assessmentId),
      subject: 'Pragyu result · $_title',
    );
  }

  Future<void> _openDeepFeedback() async {
    final snapshot = _snapshot;
    final evaluation = snapshot?.evaluation;
    if (evaluation == null || evaluation.id.isEmpty) return;

    // Slice 2.3: advanced path is opt-in after the score is understood.
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Advanced: Improve with AI',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You already have your score and feedback above. '
                  'Deep Feedback can rewrite your answer and suggest improvements — it is optional.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF7A8499),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0A3)),
                  ),
                  child: Text(
                    'Uses AI credits (about ${AiCreditCosts.rewriteRequest} per rewrite; '
                    'tips about ${AiCreditCosts.suggestionGenerate}). '
                    'Buy more anytime under Me → Payments.',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF8A5A00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Continue to Deep Feedback'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay on this result'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (proceed != true || !mounted) return;

    Navigator.of(context).pushNamed(
      AppRoutes.deepFeedback,
      arguments: DeepFeedbackArgs(
        submissionId: widget.args.submissionId,
        evaluationId: evaluation.id,
        feedbackId: snapshot?.feedback?.id,
        assessmentId: widget.args.assessmentId ?? evaluation.assessmentId,
        title: widget.args.title,
      ),
    );
  }

  void _nextScore() {
    final scores = _snapshot?.scores ?? const [];
    if (scores.isEmpty) return;
    setState(() {
      _scoreIndex = (_scoreIndex + 1) % scores.length;
      _mainTab = _MainTab.aiEvaluation;
      _detailTab = _DetailTab.detailed;
    });
  }

  void _practiceAgain() {
    final snapshot = _snapshot;
    final assessmentId = (widget.args.assessmentId ??
            snapshot?.evaluation?.assessmentId ??
            snapshot?.submission.assessmentId)
        ?.trim();
    if (assessmentId == null || assessmentId.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.attemptInstructions,
      arguments: AttemptInstructionsArgs(
        assessmentId: assessmentId,
        title: widget.args.title ?? _title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : _error != null && _snapshot == null
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : Column(
                      children: [
                        _EvalHeader(
                          title: 'AI Evaluation',
                          subtitle: _title,
                          onBack: () => Navigator.of(context).maybePop(),
                          onShare: _snapshot == null ? null : _shareSummary,
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            color: _blue,
                            onRefresh: _load,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_error != null) ...[
                                    Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFC0392B),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (_snapshot != null)
                                    ..._buildBody(_snapshot!),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_snapshot != null)
                          _BottomActions(
                            hasScores: _snapshot!.scores.isNotEmpty,
                            onModelAnswer: () {
                              setState(() => _mainTab = _MainTab.modelAnswer);
                            },
                            onDownload: _shareSummary,
                            onNext: _snapshot!.scores.isNotEmpty
                                ? _nextScore
                                : null,
                          ),
                      ],
                    ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(ResultFeedbackSnapshot snapshot) {
    final feedback = snapshot.feedback;
    final evaluationSummary = snapshot.evaluation?.feedbackSummary;
    final answerText = _originalAnswer;
    final answerImages = _answerImages;
    final scores = snapshot.scores;
    final selectedScore =
        scores.isEmpty ? null : scores[_scoreIndex.clamp(0, scores.length - 1)];
    final summaryText = (feedback?.summary ?? evaluationSummary)?.trim();
    final dimensions = _dimensionCards(
      selectedScore: selectedScore,
      scores: scores,
      feedback: feedback,
    );
    final practiceAssessmentId = (widget.args.assessmentId ??
            snapshot.evaluation?.assessmentId ??
            snapshot.submission.assessmentId)
        .trim();
    final canPractice = practiceAssessmentId.isNotEmpty;

    // Slice 2.1: first paint answers “how did I do?” — score + S/W + Practice Again.
    // Explore tabs (answer / details / model) stay secondary below.
    return [
      _QuestionMeta(
        title: scores.isEmpty
            ? _title
            : 'Q${_scoreIndex + 1}. $_title',
        marks: selectedScore?.maxScore ?? snapshot.maxScore,
        attemptNumber: snapshot.submission.attemptNumber,
        submittedAt: snapshot.submission.submittedAt ??
            snapshot.evaluation?.completedAt,
        grade: snapshot.evaluation?.grade,
      ),
      const SizedBox(height: 14),
      _OverallScoreCard(
        snapshot: snapshot,
        selectedScore: selectedScore,
      ),
      if (summaryText != null && summaryText.isNotEmpty) ...[
        const SizedBox(height: 14),
        _QuoteSummaryCard(summary: summaryText),
      ],
      const SizedBox(height: 14),
      _HowDidIDoHighlights(feedback: feedback),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: canPractice ? _practiceAgain : null,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          minimumSize: const Size.fromHeight(48),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Practice Again'),
      ),
      const SizedBox(height: 20),
      const _SectionTitle(title: 'Explore details'),
      const SizedBox(height: 10),
      _MainTabBar(
        selected: _mainTab,
        onChanged: (tab) => setState(() => _mainTab = tab),
      ),
      const SizedBox(height: 14),
      if (_mainTab == _MainTab.yourAnswer)
        _YourAnswerPanel(
          answerText: answerText,
          images: answerImages,
        )
      else if (_mainTab == _MainTab.modelAnswer)
        _ModelAnswerPanel(
          canImprove: snapshot.evaluation != null &&
              snapshot.evaluation!.id.isNotEmpty,
          onImprove: _openDeepFeedback,
        )
      else if (_mainTab == _MainTab.comparative)
        _ComparativePanel(
          answerText: answerText,
          summary: feedback?.summary ?? evaluationSummary,
          onImprove: snapshot.evaluation != null &&
                  snapshot.evaluation!.id.isNotEmpty
              ? _openDeepFeedback
              : null,
        )
      else ...[
        _AnswerPreviewCard(
          answerText: answerText,
          images: answerImages,
        ),
        const SizedBox(height: 16),
        _DetailTabBar(
          selected: _detailTab,
          onChanged: (tab) => setState(() => _detailTab = tab),
        ),
        const SizedBox(height: 12),
        if (_detailTab == _DetailTab.detailed) ...[
          if (dimensions.isEmpty && scores.isEmpty)
            const _MutedCard(
              child: Text(
                'Detailed feedback appears after AI scoring completes.',
                style: TextStyle(color: Color(0xFF7A8499), height: 1.4),
              ),
            )
          else ...[
            for (final card in dimensions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: card,
              ),
            if (scores.length > 1) ...[
              const SizedBox(height: 4),
              const _SectionTitle(title: 'Question scores'),
              const SizedBox(height: 10),
              ...scores.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final score = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ScoreTile(
                    index: index,
                    score: score,
                    selected: entry.key == _scoreIndex,
                    onTap: () => setState(() => _scoreIndex = entry.key),
                  ),
                );
              }),
            ],
          ],
        ] else ...[
          if (feedback?.tips.isNotEmpty == true)
            _BulletCard(
              title: 'Suggested Answer tips',
              items: feedback!.tips,
              accent: _blue,
              soft: _blueSoft,
            )
          else
            const _MutedCard(
              child: Text(
                'Suggested improvements appear after AI scoring completes.',
                style: TextStyle(color: Color(0xFF7A8499), height: 1.4),
              ),
            ),
          if (feedback != null && feedback.improvementAreas.isNotEmpty) ...[
            const SizedBox(height: 10),
            _BulletCard(
              title: 'Missing concepts',
              items: feedback.improvementAreas,
              accent: _purple,
              soft: _purpleSoft,
            ),
          ],
          if (snapshot.evaluation != null &&
              snapshot.evaluation!.id.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _openDeepFeedback,
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Advanced · Improve with AI'),
            ),
          ],
        ],
      ],
    ];
  }

  List<_DimensionFeedbackCard> _dimensionCards({
    required EvaluationScoreItem? selectedScore,
    required List<EvaluationScoreItem> scores,
    required EvaluationFeedbackReport? feedback,
  }) {
    final palette = <(Color, Color, IconData)>[
      (const Color(0xFFE8F8EF), const Color(0xFF22A06B), Icons.menu_book_outlined),
      (const Color(0xFFE8F1FF), const Color(0xFF2F7BFF), Icons.account_tree_outlined),
      (const Color(0xFFF3E9FF), const Color(0xFF7B5CFF), Icons.insights_outlined),
      (const Color(0xFFFFF1E0), const Color(0xFFC47A1A), Icons.edit_note_rounded),
    ];

    final rubric = selectedScore?.rubricBreakdown.entries.toList() ?? const [];
    if (rubric.isNotEmpty) {
      return [
        for (var i = 0; i < rubric.length && i < 4; i++)
          _DimensionFeedbackCard(
            title: _prettyDimension(rubric[i].key),
            scoreLabel: '${rubric[i].value}',
            body: selectedScore?.feedback?.trim().isNotEmpty == true
                ? selectedScore!.feedback!.trim()
                : 'AI scored this dimension from your answer.',
            soft: palette[i % palette.length].$1,
            accent: palette[i % palette.length].$2,
            icon: palette[i % palette.length].$3,
          ),
      ];
    }

    if (scores.isNotEmpty) {
      return [
        for (var i = 0; i < scores.length && i < 4; i++)
          _DimensionFeedbackCard(
            title: 'Question ${i + 1}',
            scoreLabel: scores[i].scoreLabel,
            body: (scores[i].feedback ?? '').trim().isNotEmpty
                ? scores[i].feedback!.trim()
                : 'Open this question score for more detail.',
            soft: palette[i % palette.length].$1,
            accent: palette[i % palette.length].$2,
            icon: palette[i % palette.length].$3,
          ),
      ];
    }

    final cards = <_DimensionFeedbackCard>[];
    if (feedback?.strengths.isNotEmpty == true) {
      cards.add(
        _DimensionFeedbackCard(
          title: 'Content Analysis',
          scoreLabel: 'Strengths',
          body: feedback!.strengths.take(2).join(' '),
          soft: palette[0].$1,
          accent: palette[0].$2,
          icon: palette[0].$3,
        ),
      );
    }
    if (feedback?.weaknesses.isNotEmpty == true) {
      cards.add(
        _DimensionFeedbackCard(
          title: 'Areas to Improve',
          scoreLabel: 'Focus',
          body: feedback!.weaknesses.take(2).join(' '),
          soft: palette[3].$1,
          accent: palette[3].$2,
          icon: palette[3].$3,
        ),
      );
    }
    return cards;
  }

  static String _prettyDimension(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Dimension';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _EvalHeader extends StatelessWidget {
  const _EvalHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onShare,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF1A2B4C),
                ),
              ),
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PragyuLogo(
                    height: 36,
                    semanticsLabel: 'Pragyu',
                  ),
                ),
              ),
              if (onShare != null)
                narrow
                    ? IconButton(
                        tooltip: 'Copy summary',
                        onPressed: onShare,
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: Color(0xFF2F7BFF),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: onShare,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2F7BFF),
                          side: const BorderSide(color: Color(0xFF2F7BFF)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy summary'),
                      ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: narrow ? 20 : 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2B4C),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: Color(0xFF7A8499),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
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

class _QuestionMeta extends StatelessWidget {
  const _QuestionMeta({
    required this.title,
    required this.marks,
    required this.attemptNumber,
    required this.submittedAt,
    required this.grade,
  });

  final String title;
  final double? marks;
  final int? attemptNumber;
  final DateTime? submittedAt;
  final String? grade;

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String)>[
      if (grade != null && grade!.isNotEmpty)
        (Icons.workspace_premium_outlined, 'Grade $grade'),
      if (marks != null)
        (
          Icons.list_alt_rounded,
          marks == marks!.roundToDouble()
              ? '${marks!.round()} Marks'
              : '$marks Marks',
        ),
      if (attemptNumber != null)
        (Icons.replay_rounded, 'Attempt $attemptNumber'),
      if (submittedAt != null)
        (Icons.calendar_today_outlined, _formatSubmitted(submittedAt!)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          softWrap: true,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B4C),
            height: 1.3,
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE6EAF2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(chip.$1, size: 14, color: const Color(0xFF2F7BFF)),
                      const SizedBox(width: 6),
                      Text(
                        chip.$2,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2B4C),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _formatSubmitted(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    final min = value.minute.toString().padLeft(2, '0');
    return 'Submitted on ${value.day} ${months[value.month - 1]} ${value.year}, $hour:$min $ampm';
  }
}

class _MainTabBar extends StatelessWidget {
  const _MainTabBar({required this.selected, required this.onChanged});

  final _MainTab selected;
  final ValueChanged<_MainTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <(_MainTab, String)>[
      (_MainTab.yourAnswer, 'Your Answer'),
      (_MainTab.aiEvaluation, 'AI Evaluation'),
      (_MainTab.modelAnswer, 'Model Answer'),
      (_MainTab.comparative, 'Comparative View'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onChanged(tab.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected == tab.$1
                            ? const Color(0xFF2F7BFF)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.$2,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected == tab.$1
                          ? const Color(0xFF2F7BFF)
                          : const Color(0xFF7A8499),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({required this.selected, required this.onChanged});

  final _DetailTab selected;
  final ValueChanged<_DetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <(_DetailTab, String)>[
      (_DetailTab.detailed, 'Detailed Feedback'),
      (_DetailTab.suggested, 'Suggested Answer'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(tab.$2),
                selected: selected == tab.$1,
                onSelected: (_) => onChanged(tab.$1),
                selectedColor: const Color(0xFFE8F1FF),
                labelStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected == tab.$1
                      ? const Color(0xFF2F7BFF)
                      : const Color(0xFF7A8499),
                ),
                side: BorderSide(
                  color: selected == tab.$1
                      ? const Color(0xFF2F7BFF)
                      : const Color(0xFFE6EAF2),
                ),
                backgroundColor: Colors.white,
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerPreviewCard extends StatelessWidget {
  const _AnswerPreviewCard({
    required this.answerText,
    this.images = const [],
  });

  final String? answerText;
  final List<AnswerImageAttachment> images;

  @override
  Widget build(BuildContext context) {
    final text = (answerText ?? '').trim();
    String? imageUrl;
    for (final img in images) {
      final url = (img.url ?? '').trim();
      if (url.isNotEmpty) {
        imageUrl = url;
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text(
            'Your Answer Sheet',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFFF7F9FC),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _AnswerFallback(
                              text: text,
                            ),
                          )
                        : _AnswerFallback(text: text),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: const Color(0xCC1A2B4C),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _openZoom(
                          context,
                          text: text,
                          imageUrl: imageUrl,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Tap to Zoom',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
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
            ),
          ),
        ],
      ),
    );
  }

  void _openZoom(
    BuildContext context, {
    required String text,
    required String? imageUrl,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Answer'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl != null)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                if (text.isNotEmpty) ...[
                  if (imageUrl != null) const SizedBox(height: 12),
                  Text(text),
                ],
                if (imageUrl == null && text.isEmpty)
                  const Text('No answer content available.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _AnswerFallback extends StatelessWidget {
  const _AnswerFallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text.isEmpty
            ? 'Your written answer will appear here when available.'
            : text,
        softWrap: true,
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13,
          height: 1.45,
          color: text.isEmpty
              ? const Color(0xFF7A8499)
              : const Color(0xFF1A2B4C),
        ),
      ),
    );
  }
}

class _OverallScoreCard extends StatelessWidget {
  const _OverallScoreCard({
    required this.snapshot,
    required this.selectedScore,
  });

  final ResultFeedbackSnapshot snapshot;
  final EvaluationScoreItem? selectedScore;

  @override
  Widget build(BuildContext context) {
    final pct = snapshot.percentage;
    final progress = (pct == null)
        ? 0.0
        : (pct / 100).clamp(0.0, 1.0);
    final rubric = selectedScore?.rubricBreakdown.entries.toList() ?? const [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Overall Score',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF1A2B4C),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE8EEF6),
                    color: const Color(0xFF22A06B),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.scoreLabel,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2B4C),
                      ),
                    ),
                    if (snapshot.percentageLabel != null)
                      Text(
                        snapshot.percentageLabel!,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A8499),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (pct != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: Color(0xFF22A06B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: pct >= 80
                                ? 'Excellent work! '
                                : pct >= 60
                                    ? 'Good Answer! '
                                    : 'Keep practicing — ',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2B4C),
                            ),
                          ),
                          TextSpan(
                            text: pct >= 80
                                ? 'Keep refining for full marks.'
                                : pct >= 60
                                    ? 'You covered most key points with relevant examples.'
                                    : 'focus on structure and key concepts.',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF1A2B4C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (rubric.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                final palette = [
                  (
                    const Color(0xFFE8F8EF),
                    const Color(0xFF22A06B),
                    Icons.menu_book_outlined,
                  ),
                  (
                    const Color(0xFFE8F1FF),
                    const Color(0xFF2F7BFF),
                    Icons.layers_outlined,
                  ),
                  (
                    const Color(0xFFF3E9FF),
                    const Color(0xFF7B5CFF),
                    Icons.bar_chart_rounded,
                  ),
                  (
                    const Color(0xFFFFF1E0),
                    const Color(0xFFC47A1A),
                    Icons.description_outlined,
                  ),
                ];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < rubric.length && i < 4; i++)
                      SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette[i].$1,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(palette[i].$3, color: palette[i].$2, size: 16),
                              const SizedBox(height: 6),
                              Text(
                                rubric[i].key.replaceAll('_', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette[i].$2,
                                ),
                              ),
                              Text(
                                '${rubric[i].value}',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A2B4C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _YourAnswerPanel extends StatelessWidget {
  const _YourAnswerPanel({
    required this.answerText,
    this.images = const [],
  });

  final String? answerText;
  final List<AnswerImageAttachment> images;

  @override
  Widget build(BuildContext context) {
    return _AnswerPreviewCard(
      answerText: answerText,
      images: images,
    );
  }
}

class _QuoteSummaryCard extends StatelessWidget {
  const _QuoteSummaryCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: Color(0xFF2F7BFF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              softWrap: true,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF1A2B4C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionFeedbackCard extends StatelessWidget {
  const _DimensionFeedbackCard({
    required this.title,
    required this.scoreLabel,
    required this.body,
    required this.soft,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String scoreLabel;
  final String body;
  final Color soft;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF1A2B4C),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        scoreLabel,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    height: 1.4,
                    color: Color(0xFF7A8499),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

class _ModelAnswerPanel extends StatelessWidget {
  const _ModelAnswerPanel({
    required this.canImprove,
    required this.onImprove,
  });

  final bool canImprove;
  final VoidCallback onImprove;

  @override
  Widget build(BuildContext context) {
    return _MutedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Model Answer',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2B4C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional advanced tools can rewrite your answer with AI after you understand your score. Uses AI credits.',
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Color(0xFF7A8499),
              height: 1.4,
            ),
          ),
          if (canImprove) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onImprove,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2F7BFF),
                side: const BorderSide(color: Color(0xFF2F7BFF)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Advanced · Improve with AI'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparativePanel extends StatelessWidget {
  const _ComparativePanel({
    required this.answerText,
    required this.summary,
    required this.onImprove,
  });

  final String? answerText;
  final String? summary;
  final VoidCallback? onImprove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AnswerPreviewCard(answerText: answerText),
        const SizedBox(height: 12),
        _MutedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Comparative View',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2B4C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (summary ?? '').trim().isEmpty
                    ? 'Compare your answer with AI improvements after generating a rewrite.'
                    : summary!.trim(),
                softWrap: true,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Color(0xFF7A8499),
                  height: 1.4,
                ),
              ),
              if (onImprove != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onImprove,
                  child: const Text('Advanced · Improve with AI'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.hasScores,
    required this.onModelAnswer,
    required this.onDownload,
    required this.onNext,
  });

  final bool hasScores;
  final VoidCallback onModelAnswer;
  final VoidCallback onDownload;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wrap = constraints.maxWidth < 520;
              final buttons = <Widget>[
                OutlinedButton.icon(
                  onPressed: onModelAnswer,
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text('View Model Answer'),
                ),
                OutlinedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy report'),
                ),
                FilledButton.icon(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F7BFF),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(hasScores ? 'Next Question' : 'Next'),
                ),
              ];
              if (wrap) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final button in buttons)
                      SizedBox(
                        width: (constraints.maxWidth - 8) / 2,
                        child: button,
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: buttons[i]),
                  ],
                ],
              );
            },
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(color: Color(0xFFC0392B), height: 1.4),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F7BFF),
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

class _HowDidIDoHighlights extends StatelessWidget {
  const _HowDidIDoHighlights({required this.feedback});

  final EvaluationFeedbackReport? feedback;

  @override
  Widget build(BuildContext context) {
    final strengths = feedback?.strengths ?? const <String>[];
    final weaknesses = feedback?.weaknesses ?? const <String>[];
    if (strengths.isEmpty && weaknesses.isEmpty) {
      return const _MutedCard(
        child: Text(
          'Strengths and focus areas appear here after AI scoring completes.',
          style: TextStyle(color: Color(0xFF7A8499), height: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (strengths.isNotEmpty)
          _BulletCard(
            title: 'Key Strengths',
            items: strengths.take(3).toList(growable: false),
            accent: const Color(0xFF22A06B),
            soft: const Color(0xFFE8F8EF),
          ),
        if (strengths.isNotEmpty && weaknesses.isNotEmpty)
          const SizedBox(height: 10),
        if (weaknesses.isNotEmpty)
          _BulletCard(
            title: 'Areas for Improvement',
            items: weaknesses.take(3).toList(growable: false),
            accent: const Color(0xFFE85D75),
            soft: const Color(0xFFFDE8EC),
          ),
      ],
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
        fontFamily: AppTheme.fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A2B4C),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: child,
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.index,
    required this.score,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final EvaluationScoreItem score;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final criteria = score.rubricBreakdown.entries.toList(growable: false);
    return Material(
      color: selected ? const Color(0xFFE8F1FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2F7BFF)
                  : const Color(0xFFE6EAF2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question $index · ${score.scoreLabel}',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2B4C),
                ),
              ),
              if (score.feedback != null && score.feedback!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  score.feedback!,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Color(0xFF1A2B4C),
                    height: 1.4,
                  ),
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
                              color: Color(0xFF7A8499),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2B4C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.title,
    required this.items,
    required this.accent,
    required this.soft,
  });

  final String title;
  final List<String> items;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: soft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
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
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Color(0xFF1A2B4C),
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
