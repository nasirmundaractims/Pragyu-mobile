import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// Bottom-nav hub for AI Evaluation — lists evaluated attempts and opens S-46.
class AiEvaluationHubScreen extends StatefulWidget {
  const AiEvaluationHubScreen({
    super.key,
    this.testsRepository,
  });

  final TestsGateway? testsRepository;

  @override
  State<AiEvaluationHubScreen> createState() => _AiEvaluationHubScreenState();
}

class _AiEvaluationHubScreenState extends State<AiEvaluationHubScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _pageBg = Color(0xFFF8FAFD);

  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();

  bool _loading = true;
  String? _error;
  PastResultsSnapshot? _snapshot;
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
            : 'Unable to load AI evaluations.';
      });
    }
  }

  List<SubmissionSummary> _items(PastResultsSnapshot snapshot) {
    final query = _query.trim().toLowerCase();
    final ready = snapshot.scores;
    if (query.isEmpty) return ready;
    return ready.where((item) {
      final title = snapshot.titleFor(item.assessmentId).toLowerCase();
      return title.contains(query) ||
          item.status.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void _openEvaluation(SubmissionSummary item) {
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
                          PragyuLogo(height: 34, semanticsLabel: 'Pragyu'),
                          SizedBox(height: 4),
                          Text(
                            'Learn • Practice • Grow',
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
                child: _loading && _snapshot == null
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
                              'Open evaluated attempts to review scores, feedback, and model answers.',
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                height: 1.4,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search evaluations',
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
                            if (_snapshot != null) ..._buildList(_snapshot!),
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

  List<Widget> _buildList(PastResultsSnapshot snapshot) {
    final items = _items(snapshot);
    if (snapshot.scores.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text(
            'No AI evaluations yet.\nSubmit a practice test to see feedback here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: _muted,
              height: 1.45,
            ),
          ),
        ),
      ];
    }
    if (items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text(
            'No evaluations match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: _muted,
              height: 1.45,
            ),
          ),
        ),
      ];
    }

    return [
      Text(
        '${items.length} evaluation${items.length == 1 ? '' : 's'}',
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      const SizedBox(height: 12),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EvaluationCard(
            title: snapshot.titleFor(item.assessmentId),
            item: item,
            onTap: () => _openEvaluation(item),
          ),
        ),
    ];
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({
    required this.title,
    required this.item,
    required this.onTap,
  });

  final String title;
  final SubmissionSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = formatScorePair(item.totalScore, item.maxScore);
    final pct = item.percentage;
    final pctLabel = pct == null
        ? null
        : (pct == pct.roundToDouble()
            ? '${pct.round()}%'
            : '${pct.toStringAsFixed(1)}%');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F1FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF2F7BFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF1A2B4C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Attempt ${item.attemptNumber}',
                        if (pctLabel != null) pctLabel,
                        submissionStatusLabel(item.status),
                      ].join(' · '),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: Color(0xFF7A8499),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF22A06B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22A06B),
                      ),
                    ),
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
