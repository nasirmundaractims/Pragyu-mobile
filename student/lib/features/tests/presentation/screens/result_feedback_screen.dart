import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
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

enum _DetailTab { detailed, strengths, improvements, suggested }

class _ResultFeedbackScreenState extends State<ResultFeedbackScreen> {
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _pageBg = Color(0xFFF8FAFD);
  static const _green = Color(0xFF22A06B);
  static const _greenSoft = Color(0xFFE8F8EF);
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
        _scoreIndex = 0;
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

  Future<void> _shareSummary() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final buffer = StringBuffer()
      ..writeln('Pragyu AI Evaluation')
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
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Evaluation summary copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openDeepFeedback() {
    final snapshot = _snapshot;
    final evaluation = snapshot?.evaluation;
    if (evaluation == null || evaluation.id.isEmpty) return;
    Navigator.of(context).pushNamed(
      AppRoutes.deepFeedback,
      arguments: DeepFeedbackArgs(
        submissionId: widget.args.submissionId,
        evaluationId: evaluation.id,
        feedbackId: snapshot?.feedback?.id,
        assessmentId:
            widget.args.assessmentId ?? evaluation.assessmentId,
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
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                                if (_snapshot != null) ..._buildBody(_snapshot!),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_snapshot != null)
                          _BottomActions(
                            canDeep: _snapshot!.evaluation != null &&
                                _snapshot!.evaluation!.id.isNotEmpty,
                            hasScores: _snapshot!.scores.isNotEmpty,
                            onModelAnswer: () {
                              setState(() => _mainTab = _MainTab.modelAnswer);
                            },
                            onDownload: _shareSummary,
                            onPracticeAgain: () =>
                                Navigator.of(context).maybePop(),
                            onNext: _snapshot!.scores.isNotEmpty
                                ? _nextScore
                                : null,
                            onImprove: _openDeepFeedback,
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
    final scores = snapshot.scores;
    final selectedScore =
        scores.isEmpty ? null : scores[_scoreIndex.clamp(0, scores.length - 1)];

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
      _MainTabBar(
        selected: _mainTab,
        onChanged: (tab) => setState(() => _mainTab = tab),
      ),
      const SizedBox(height: 14),
      if (_mainTab == _MainTab.yourAnswer)
        _YourAnswerPanel(answerText: answerText)
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
        _ScoreAndAnswerRow(
          snapshot: snapshot,
          answerText: answerText,
          selectedScore: selectedScore,
        ),
        const SizedBox(height: 16),
        _DetailTabBar(
          selected: _detailTab,
          onChanged: (tab) => setState(() => _detailTab = tab),
        ),
        const SizedBox(height: 12),
        if (_detailTab == _DetailTab.detailed) ...[
          const _SectionTitle(title: 'Score breakdown'),
          const SizedBox(height: 10),
          if (scores.isEmpty)
            _MutedCard(
              child: Text(
                'Question scores appear when AI evaluation finishes.',
                style: TextStyle(color: Color(0xFF7A8499), height: 1.4),
              ),
            )
          else
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
          const SizedBox(height: 12),
          if (feedback == null || !feedback.hasContent)
            _MutedCard(
              child: Text(
                evaluationSummary?.isNotEmpty == true
                    ? evaluationSummary!
                    : 'Detailed feedback appears after AI scoring completes.',
                style: const TextStyle(color: Color(0xFF7A8499), height: 1.4),
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
                accent: _green,
                soft: _greenSoft,
              ),
            ],
            if (feedback.weaknesses.isNotEmpty) ...[
              const SizedBox(height: 10),
              _BulletCard(
                title: 'Weaknesses',
                items: feedback.weaknesses,
                accent: const Color(0xFFE85D75),
                soft: const Color(0xFFFDE8EC),
              ),
            ],
            if (feedback.improvementAreas.isNotEmpty) ...[
              const SizedBox(height: 10),
              _BulletCard(
                title: 'Improvement areas',
                items: feedback.improvementAreas,
                accent: _purple,
                soft: _purpleSoft,
              ),
            ],
            if (feedback.tips.isNotEmpty) ...[
              const SizedBox(height: 10),
              _BulletCard(
                title: 'Actionable tips',
                items: feedback.tips,
                accent: _blue,
                soft: _blueSoft,
              ),
            ],
          ],
        ] else if (_detailTab == _DetailTab.strengths) ...[
          if (feedback?.strengths.isNotEmpty == true)
            _BulletCard(
              title: 'Strengths',
              items: feedback!.strengths,
              accent: _green,
              soft: _greenSoft,
            )
          else
            _MutedCard(
              child: Text(
                'Strengths appear after AI scoring completes.',
                style: TextStyle(color: Color(0xFF7A8499), height: 1.4),
              ),
            ),
        ] else if (_detailTab == _DetailTab.improvements) ...[
          if (feedback != null &&
              (feedback.weaknesses.isNotEmpty ||
                  feedback.improvementAreas.isNotEmpty)) ...[
            if (feedback.weaknesses.isNotEmpty)
              _BulletCard(
                title: 'Weaknesses',
                items: feedback.weaknesses,
                accent: const Color(0xFFE85D75),
                soft: const Color(0xFFFDE8EC),
              ),
            if (feedback.improvementAreas.isNotEmpty) ...[
              const SizedBox(height: 10),
              _BulletCard(
                title: 'Improvement areas',
                items: feedback.improvementAreas,
                accent: _purple,
                soft: _purpleSoft,
              ),
            ],
          ] else
            _MutedCard(
              child: Text(
                'Improvement areas appear after AI scoring completes.',
                style: TextStyle(color: Color(0xFF7A8499), height: 1.4),
              ),
            ),
        ] else ...[
          if (feedback?.tips.isNotEmpty == true)
            _BulletCard(
              title: 'Actionable tips',
              items: feedback!.tips,
              accent: _blue,
              soft: _blueSoft,
            )
          else
            _MutedCard(
              child: Text(
                'Suggested improvements appear after AI scoring completes.',
                style: TextStyle(color: Color(0xFF7A8499), height: 1.4),
              ),
            ),
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
              child: const Text('Improve answer with AI'),
            ),
          ],
        ],
        if (_detailTab == _DetailTab.detailed &&
            snapshot.evaluation != null &&
            snapshot.evaluation!.id.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _openDeepFeedback,
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _blue),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Improve answer with AI'),
          ),
        ],
      ],
    ];
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
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A2B4C)),
          ),
          const PragyuLogo(height: 28, semanticsLabel: 'Pragyu'),
          if (!narrow) ...[
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Learn • Practice • Grow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: Color(0xFF7A8499),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: Color(0xFF7A8499),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (narrow)
            IconButton(
              tooltip: 'Share',
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF2F7BFF)),
            )
          else
            OutlinedButton.icon(
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
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text('Share'),
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
      (_DetailTab.strengths, 'Key Strengths'),
      (_DetailTab.improvements, 'Areas for Improvement'),
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

class _ScoreAndAnswerRow extends StatelessWidget {
  const _ScoreAndAnswerRow({
    required this.snapshot,
    required this.answerText,
    required this.selectedScore,
  });

  final ResultFeedbackSnapshot snapshot;
  final String? answerText;
  final EvaluationScoreItem? selectedScore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 640;
        final answerCard = _AnswerPreviewCard(answerText: answerText);
        final scoreCard = _OverallScoreCard(
          snapshot: snapshot,
          selectedScore: selectedScore,
        );
        if (stack) {
          return Column(
            children: [
              answerCard,
              const SizedBox(height: 12),
              scoreCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: answerCard),
            const SizedBox(width: 12),
            Expanded(child: scoreCard),
          ],
        );
      },
    );
  }
}

class _AnswerPreviewCard extends StatelessWidget {
  const _AnswerPreviewCard({required this.answerText});

  final String? answerText;

  @override
  Widget build(BuildContext context) {
    final text = (answerText ?? '').trim();
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
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 140),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EAF2)),
            ),
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
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: text.isEmpty
                  ? null
                  : () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Your Answer'),
                          content: SingleChildScrollView(child: Text(text)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
              icon: const Icon(Icons.zoom_in_rounded, size: 18),
              label: const Text('Tap to Zoom'),
            ),
          ),
        ],
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
              'Your score',
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
                    child: Text(
                      pct >= 80
                          ? 'Excellent work! Keep refining for full marks.'
                          : pct >= 60
                              ? 'Good Answer! You covered most key points with relevant examples.'
                              : 'Keep practicing — focus on structure and key concepts.',
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF1A2B4C),
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
  const _YourAnswerPanel({required this.answerText});

  final String? answerText;

  @override
  Widget build(BuildContext context) {
    return _AnswerPreviewCard(answerText: answerText);
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
            'Open AI rewrite tools to generate a model answer and compare improvements.',
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Color(0xFF7A8499),
              height: 1.4,
            ),
          ),
          if (canImprove) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onImprove,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2F7BFF),
              ),
              child: const Text('Improve answer with AI'),
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
                  child: const Text('Improve answer with AI'),
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
    required this.canDeep,
    required this.hasScores,
    required this.onModelAnswer,
    required this.onDownload,
    required this.onPracticeAgain,
    required this.onNext,
    required this.onImprove,
  });

  final bool canDeep;
  final bool hasScores;
  final VoidCallback onModelAnswer;
  final VoidCallback onDownload;
  final VoidCallback onPracticeAgain;
  final VoidCallback? onNext;
  final VoidCallback onImprove;

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
                  onPressed: canDeep ? onImprove : onModelAnswer,
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text('View Model Answer'),
                ),
                OutlinedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Report'),
                ),
                OutlinedButton.icon(
                  onPressed: onPracticeAgain,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Practice Again'),
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

class _OverallFeedbackCard extends StatelessWidget {
  const _OverallFeedbackCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall feedback',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F7BFF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Color(0xFF1A2B4C),
              height: 1.45,
            ),
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
