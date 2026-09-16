import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/study_planner/data/study_planner_repository.dart';
import 'package:student_mobile/features/study_planner/domain/study_planner_models.dart';

/// S-62 Study planner — plans, day sessions, and goals.
class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({
    super.key,
    this.plannerRepository,
  });

  final StudyPlannerGateway? plannerRepository;

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  late final StudyPlannerGateway _repo =
      widget.plannerRepository ?? StudyPlannerRepository();

  bool _loading = true;
  bool _generating = false;
  String? _completingGoalId;
  String? _error;
  StudyPlannerSnapshot? _snapshot;
  StudyDayName _selectedDay = todayDayName();

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
      final snapshot = await _repo.loadPlanner();
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
            : 'Unable to load study planner.';
      });
    }
  }

  Future<void> _generate() async {
    final snapshot = _snapshot;
    if (snapshot == null || _generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final plan = await _repo.generateWeeklyPlan(
        studentProfileId: snapshot.studentProfileId,
      );
      if (!mounted) return;
      setState(() {
        _generating = false;
        _snapshot = snapshot.copyWith(
          plans: [plan, ...snapshot.plans.where((p) => p.id != plan.id)],
          activePlanId: plan.id,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly study plan generated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to generate plan.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _completeGoal(LearningGoal goal) async {
    if (_completingGoalId != null) return;
    setState(() => _completingGoalId = goal.id);
    try {
      final updated = await _repo.completeGoal(goal.id);
      if (!mounted) return;
      final snapshot = _snapshot;
      if (snapshot == null) return;
      setState(() {
        _completingGoalId = null;
        _snapshot = snapshot.copyWith(
          goals: [
            for (final item in snapshot.goals)
              if (item.id == updated.id) updated else item,
          ],
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _completingGoalId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to complete goal.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final plan = snapshot?.activePlan;
    final daySessions = plan?.sessionsForDay(_selectedDay) ?? const [];
    final dayMinutes =
        daySessions.fold<int>(0, (sum, s) => sum + s.estimatedMinutes);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Study Planner'),
          actions: [
            IconButton(
              tooltip: 'Weak topics',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.weakTopics),
              icon: const Icon(Icons.track_changes_outlined),
            ),
          ],
        ),
        floatingActionButton: snapshot == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _generating ? null : _generate,
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_generating ? 'Generating…' : 'Generate week'),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                            _MetricsRow(
                              daySessions: daySessions.length,
                              dayMinutes: dayMinutes,
                              plans: snapshot?.plans.length ?? 0,
                              openGoals: snapshot?.openGoals.length ?? 0,
                              dayLabel: _selectedDay.shortLabel,
                            ),
                            const SizedBox(height: 18),
                            _SectionHeader(
                              title: 'Your plans',
                              actionLabel: snapshot?.plans.isEmpty == true
                                  ? null
                                  : 'Generate',
                              onAction: snapshot?.plans.isEmpty == true
                                  ? null
                                  : (_generating ? null : _generate),
                            ),
                            const SizedBox(height: 10),
                            if (snapshot == null || snapshot.plans.isEmpty)
                              _EmptyPlans(onGenerate: _generating ? null : _generate)
                            else
                              SizedBox(
                                height: 108,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: snapshot.plans.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final item = snapshot.plans[index];
                                    final active = item.id == plan?.id;
                                    return _PlanChip(
                                      plan: item,
                                      active: active,
                                      onTap: () => setState(() {
                                        _snapshot = snapshot.copyWith(
                                          activePlanId: item.id,
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 18),
                            const Text(
                              'This week',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _DayStrip(
                              selected: _selectedDay,
                              onSelect: (day) =>
                                  setState(() => _selectedDay = day),
                              counts: {
                                for (final day in weekDayOrder)
                                  day: plan?.sessionsForDay(day).length ?? 0,
                              },
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '${_selectedDay.label} sessions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (daySessions.isEmpty)
                              const _EmptyDay()
                            else
                              for (final period in StudyPeriod.values) ...[
                                ..._sessionsForPeriod(daySessions, period),
                              ],
                            const SizedBox(height: 22),
                            const Text(
                              'Goals',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (snapshot == null || snapshot.goals.isEmpty)
                              const _EmptyGoals()
                            else
                              for (final goal in snapshot.goals) ...[
                                _GoalCard(
                                  goal: goal,
                                  completing: _completingGoalId == goal.id,
                                  onComplete: goal.isOpen
                                      ? () => _completeGoal(goal)
                                      : null,
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

  List<Widget> _sessionsForPeriod(
    List<StudySession> sessions,
    StudyPeriod period,
  ) {
    final items = sessions.where((s) => s.period == period).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(
          _periodLabel(period),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.4,
          ),
        ),
      ),
      for (final session in items) ...[
        _SessionCard(session: session),
        const SizedBox(height: 8),
      ],
    ];
  }

  String _periodLabel(StudyPeriod period) {
    switch (period) {
      case StudyPeriod.morning:
        return 'MORNING';
      case StudyPeriod.afternoon:
        return 'AFTERNOON';
      case StudyPeriod.evening:
        return 'EVENING';
      case StudyPeriod.night:
        return 'NIGHT';
    }
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
          colors: [Color(0xFFF3FAF7), Color(0xFFEEF4FF)],
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
            'STUDY PLANNER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.success,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Plan your week with focus',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Switch plans, browse day sessions, and track study goals from your learning plan.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.daySessions,
    required this.dayMinutes,
    required this.plans,
    required this.openGoals,
    required this.dayLabel,
  });

  final int daySessions;
  final int dayMinutes;
  final int plans;
  final int openGoals;
  final String dayLabel;

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
                label: 'Selected day',
                value: '$daySessions',
                hint: dayLabel,
                color: const Color(0xFF0F766E),
                bg: const Color(0xFFE6F6F3),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Study time',
                value: '${dayMinutes}m',
                hint: 'Estimated',
                color: const Color(0xFF2F6FED),
                bg: const Color(0xFFEAF2FF),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Plans',
                value: '$plans',
                hint: 'Saved plans',
                color: AppColors.brand,
                bg: AppColors.brandSoft,
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Open goals',
                value: '$openGoals',
                hint: 'Still active',
                color: const Color(0xFFB86E00),
                bg: const Color(0xFFFFF4E5),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.plan,
    required this.active,
    required this.onTap,
  });

  final StudyPlan plan;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Material(
        color: active ? AppColors.brandSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? AppColors.brand : AppColors.brandSoft,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${plan.planType} · ${plan.sessions.length} tasks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.selected,
    required this.onSelect,
    required this.counts,
  });

  final StudyDayName selected;
  final ValueChanged<StudyDayName> onSelect;
  final Map<StudyDayName, int> counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in weekDayOrder)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: day == selected ? AppColors.brand : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onSelect(day),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: day == selected
                            ? AppColors.brand
                            : AppColors.brandSoft,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          day.shortLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: day == selected
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${counts[day] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            color: day == selected
                                ? Colors.white70
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final StudySession session;

  Color get _priorityColor {
    switch (session.priority) {
      case SessionPriority.high:
        return AppColors.danger;
      case SessionPriority.medium:
        return const Color(0xFFE67E22);
      case SessionPriority.low:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${session.subject} · ${session.kind}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            session.timeLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
          if (session.description != null &&
              session.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              session.description!,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.completing,
    this.onComplete,
  });

  final LearningGoal goal;
  final bool completing;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                  goal.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: goal.isCompleted
                        ? AppColors.muted
                        : AppColors.ink,
                    decoration: goal.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal.progressLabel,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (goal.isCompleted)
            const Icon(Icons.check_circle, color: AppColors.success)
          else
            TextButton(
              onPressed: completing ? null : onComplete,
              child: completing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  : const Text('Complete'),
            ),
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({this.onGenerate});

  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 34, color: AppColors.brand),
          const SizedBox(height: 10),
          const Text(
            'No plans yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate a weekly study plan from your weak topics and learning signals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onGenerate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate weekly plan'),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

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
      child: const Text(
        'No sessions scheduled for this day.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.4),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

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
      child: const Text(
        'No learning goals yet. Goals appear when your institute or plan sets them.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.4),
      ),
    );
  }
}
