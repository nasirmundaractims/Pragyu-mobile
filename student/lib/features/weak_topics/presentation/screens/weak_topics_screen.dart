import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/weak_topics/data/weak_topics_repository.dart';
import 'package:student_mobile/features/weak_topics/domain/weak_topics_models.dart';

/// S-61 Weak topics — focus list from mastery signals.
class WeakTopicsScreen extends StatefulWidget {
  const WeakTopicsScreen({
    super.key,
    this.weakTopicsRepository,
  });

  final WeakTopicsGateway? weakTopicsRepository;

  @override
  State<WeakTopicsScreen> createState() => _WeakTopicsScreenState();
}

class _WeakTopicsScreenState extends State<WeakTopicsScreen> {
  late final WeakTopicsGateway _repo =
      widget.weakTopicsRepository ?? WeakTopicsRepository();

  bool _loading = true;
  String? _error;
  WeakTopicsSnapshot? _snapshot;
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
      final snapshot = await _repo.loadWeakTopics();
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
            : 'Unable to load weak topics.';
      });
    }
  }

  void _openMentor() {
    Navigator.of(context).pushNamed(AppRoutes.aiMentor);
  }

  List<WeakTopicItem> get _filtered {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    final q = _query.trim().toLowerCase();
    final focus = snapshot.focusTopics;
    if (q.isEmpty) return focus;
    return focus
        .where(
          (t) =>
              t.name.toLowerCase().contains(q) ||
              t.whyShown.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Weak Topics'),
          actions: [
            IconButton(
              tooltip: 'Ask AI Mentor',
              onPressed: _openMentor,
              icon: const Icon(Icons.auto_awesome),
            ),
          ],
        ),
        body: SafeArea(
          child: _loading && _snapshot == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && _snapshot == null
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
                            const _HeroBanner(),
                            const SizedBox(height: 14),
                            if (_snapshot != null) ...[
                              _MetricsRow(
                                needsWork: _snapshot!.needsWorkCount,
                                improving: _snapshot!.improvingCount,
                                turningAround: _snapshot!.turningAroundCount,
                                onAskMentor: _openMentor,
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'Search focus topics…',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandSoft,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandSoft,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Your focus list',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Each card explains why it is shown and what to do next.',
                              style: TextStyle(
                                color: AppColors.muted,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_filtered.isEmpty)
                              const _EmptyFocus()
                            else
                              for (final topic in _filtered) ...[
                                _TopicCard(
                                  topic: topic,
                                  onAskMentor: _openMentor,
                                ),
                                const SizedBox(height: 10),
                              ],
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
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7F7), Color(0xFFF3F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEAK TOPICS & IMPROVEMENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.danger,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Focus where it matters most',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Topics appear when evaluations show low mastery. As you improve, they move to Improving or drop off once you are performing well.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.needsWork,
    required this.improving,
    required this.turningAround,
    required this.onAskMentor,
  });

  final int needsWork;
  final int improving;
  final int turningAround;
  final VoidCallback onAskMentor;

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
              child: _MetricCard(
                label: 'Needs work',
                value: '$needsWork',
                hint: 'Priority focus',
                color: const Color(0xFFC0392B),
                bg: const Color(0xFFFDEDEC),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Improving',
                value: '$improving',
                hint: 'Former weak areas',
                color: const Color(0xFF2F6FED),
                bg: const Color(0xFFEAF2FF),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Turning around',
                value: '$turningAround',
                hint: 'Strong or nearly',
                color: AppColors.success,
                bg: const Color(0xFFE7F8EF),
              ),
            ),
            SizedBox(
              width: width,
              child: Material(
                color: const Color(0xFFF0EBFF),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onAskMentor,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask Mentor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B4E9B),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Coach',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Explain a weak topic',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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

class _EmptyFocus extends StatelessWidget {
  const _EmptyFocus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, size: 36, color: AppColors.success),
          SizedBox(height: 12),
          Text(
            'No weak topics right now',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Great news — nothing is flagged as weak. Keep practicing or take a test so we can spot new gaps.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.onAskMentor,
  });

  final WeakTopicItem topic;
  final VoidCallback onAskMentor;

  Color get _badgeBg {
    switch (topic.status) {
      case TopicMasteryStatus.improving:
        return const Color(0xFFEAF2FF);
      case TopicMasteryStatus.strong:
        return const Color(0xFFE7F8EF);
      case TopicMasteryStatus.needsRevision:
        return const Color(0xFFFFF4E5);
      case TopicMasteryStatus.weak:
        return const Color(0xFFFDEDEC);
    }
  }

  Color get _badgeFg {
    switch (topic.status) {
      case TopicMasteryStatus.improving:
        return const Color(0xFF2F6FED);
      case TopicMasteryStatus.strong:
        return AppColors.success;
      case TopicMasteryStatus.needsRevision:
        return const Color(0xFFB86E00);
      case TopicMasteryStatus.weak:
        return AppColors.danger;
    }
  }

  Color get _barColor {
    if (topic.mastery < 45) return AppColors.danger;
    if (topic.mastery < 55) return const Color(0xFFE67E22);
    return const Color(0xFFD4A017);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        topic.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _badgeFg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      topic.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topic.whyShown,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MasteryRing(value: topic.mastery, color: _barColor),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: topic.mastery / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EDF5),
              color: _barColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetaChip(
                  label: 'Difficulty',
                  value: topic.difficulty,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaChip(
                  label: 'Attempts',
                  value: topic.attempts?.toString() ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAskMentor,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Ask Mentor'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brandSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryRing extends StatelessWidget {
  const _MasteryRing({
    required this.value,
    required this.color,
  });

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 5,
              backgroundColor: const Color(0xFFE8EDF5),
              color: color,
            ),
          ),
          Text(
            '$value%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
