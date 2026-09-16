import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/analytics/data/analytics_repository.dart';
import 'package:student_mobile/features/analytics/domain/analytics_models.dart';

/// S-65 My Performance — learning analytics journey and insights.
class PerformanceAnalyticsScreen extends StatefulWidget {
  const PerformanceAnalyticsScreen({
    super.key,
    this.analyticsRepository,
  });

  final AnalyticsGateway? analyticsRepository;

  @override
  State<PerformanceAnalyticsScreen> createState() =>
      _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState
    extends State<PerformanceAnalyticsScreen> {
  late final AnalyticsGateway _repo =
      widget.analyticsRepository ?? AnalyticsRepository();

  bool _loading = true;
  String? _error;
  PerformanceSnapshot? _snapshot;

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
      final snapshot = await _repo.loadPerformance();
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
            : 'Unable to load performance analytics.';
      });
    }
  }

  String _pct(double? value) {
    if (value == null) return '—';
    return '${value.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('My Performance'),
          actions: [
            IconButton(
              tooltip: 'Weak topics',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.weakTopics),
              icon: const Icon(Icons.track_changes_outlined),
            ),
          ],
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
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            _HeroBanner(
                              level: snapshot?.levelLabel ?? 'Starter',
                              period: snapshot?.periodType,
                              snapshotDate: snapshot?.snapshotDate,
                            ),
                            const SizedBox(height: 14),
                            _KpiGrid(
                              overall: _pct(snapshot?.overallAverage),
                              progress: _pct(snapshot?.learningProgress),
                              streak: (snapshot?.streak ?? 0) == 0
                                  ? '—'
                                  : '${snapshot!.streak}d',
                              completed:
                                  '${snapshot?.completedAssessments ?? 0}',
                              practice: '${snapshot?.practiceSessions ?? 0}',
                              improvement: snapshot?.improvement == null
                                  ? null
                                  : '${snapshot!.improvement! >= 0 ? '+' : ''}${snapshot.improvement!.round()}%',
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'AI insights',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final insight
                                in snapshot?.insights ?? const <PerformanceInsight>[]) ...[
                              _InsightCard(insight: insight),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 10),
                            const Text(
                              'Subject analysis',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (snapshot == null || snapshot.subjects.isEmpty)
                              const _EmptyCard(
                                title: 'No subject scores yet',
                                body:
                                    'Evaluated assessments will appear here with averages and trends.',
                              )
                            else
                              for (final subject in snapshot.subjects) ...[
                                _SubjectCard(subject: subject),
                                const SizedBox(height: 10),
                              ],
                            const SizedBox(height: 10),
                            const Text(
                              'Score trend',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (snapshot == null ||
                                snapshot.scoreTrend.isEmpty)
                              const _EmptyCard(
                                title: 'No score trend yet',
                                body:
                                    'Complete a few evaluated attempts to see your progress over time.',
                              )
                            else
                              _TrendList(points: snapshot.scoreTrend),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.weakTopics),
                                  icon: const Icon(Icons.track_changes_outlined),
                                  label: const Text('Weak topics'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.recommendations),
                                  icon: const Icon(Icons.lightbulb_outline),
                                  label: const Text('Recommendations'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.pastResults),
                                  icon: const Icon(Icons.assignment_outlined),
                                  label: const Text('Past results'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
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

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.level,
    this.period,
    this.snapshotDate,
  });

  final String level;
  final String? period;
  final String? snapshotDate;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (period != null && period!.isNotEmpty) period!,
      if (snapshotDate != null && snapshotDate!.isNotEmpty) snapshotDate!,
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF8F4), Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LEARNING JOURNEY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta.isEmpty
                ? 'Track scores, streaks, and subject strengths from your latest work.'
                : meta,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.overall,
    required this.progress,
    required this.streak,
    required this.completed,
    required this.practice,
    this.improvement,
  });

  final String overall;
  final String progress;
  final String streak;
  final String completed;
  final String practice;
  final String? improvement;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _KpiCard(
                label: 'Overall score',
                value: overall,
                hint: improvement == null
                    ? 'Across evaluated attempts'
                    : 'Trend $improvement',
                color: const Color(0xFF0F766E),
                bg: const Color(0xFFE6F6F3),
              ),
            ),
            SizedBox(
              width: width,
              child: _KpiCard(
                label: 'Learning progress',
                value: progress,
                hint: 'Journey completion',
                color: const Color(0xFF6B4E9B),
                bg: const Color(0xFFF0EBFF),
              ),
            ),
            SizedBox(
              width: width,
              child: _KpiCard(
                label: 'Study streak',
                value: streak,
                hint: 'Days with submissions',
                color: const Color(0xFFE67E22),
                bg: const Color(0xFFFFF4E5),
              ),
            ),
            SizedBox(
              width: width,
              child: _KpiCard(
                label: 'Completed',
                value: completed,
                hint: 'Feedback ready',
                color: AppColors.success,
                bg: const Color(0xFFE7F8EF),
              ),
            ),
            SizedBox(
              width: width,
              child: _KpiCard(
                label: 'Accuracy',
                value: overall,
                hint: 'Score accuracy',
                color: const Color(0xFF2F6FED),
                bg: const Color(0xFFEAF2FF),
              ),
            ),
            SizedBox(
              width: width,
              child: _KpiCard(
                label: 'Practice',
                value: practice,
                hint: 'From learning snapshot',
                color: const Color(0xFFD94F8B),
                bg: const Color(0xFFFFEAF2),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    required this.bg,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final PerformanceInsight insight;

  @override
  Widget build(BuildContext context) {
    final tone = insight.isHigh
        ? (bg: const Color(0xFFFDEDEC), fg: AppColors.danger)
        : (bg: const Color(0xFFEAF2FF), fg: const Color(0xFF2F6FED));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tone.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              insight.priority.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tone.fg,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.detail,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.35,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '~${insight.minutes} min',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final SubjectPerformance subject;

  Color get _barColor {
    final avg = subject.average ?? 0;
    if (avg >= 85) return AppColors.success;
    if (avg >= 70) return const Color(0xFF2F6FED);
    if (avg >= 50) return const Color(0xFFE67E22);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final avg = subject.average;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                avg == null ? '—' : '${avg.round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ((avg ?? 0) / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EDF5),
              color: _barColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${subject.statusLabel} · ${subject.count} attempts'
            '${subject.improvement == null ? '' : ' · ${subject.improvement! >= 0 ? '+' : ''}${subject.improvement!.round()}%'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TrendList extends StatelessWidget {
  const _TrendList({required this.points});

  final List<ScoreTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final point in points.reversed) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brandSoft),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (point.at != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          point.at!.toLocal().toIso8601String().substring(0, 10),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  point.percentage == null
                      ? '—'
                      : '${point.percentage!.round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
