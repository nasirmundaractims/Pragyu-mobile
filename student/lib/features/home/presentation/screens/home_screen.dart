import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/shell/feature_placeholder_screen.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/greeting.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/learn/presentation/screens/my_learning_screen.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/presentation/screens/tests_hub_screen.dart';

/// S-10 Home — dashboard matching Pragyu home design.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.homeRepository,
  });

  final HomeGateway? homeRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF4A7DFF);
  static const _purple = Color(0xFF7C5CFF);
  static const _green = Color(0xFF22A06B);

  late final HomeGateway _home = widget.homeRepository ?? HomeRepository();

  bool _loading = true;
  String? _error;
  HomeSnapshot? _snapshot;

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
      final snapshot = await _home.loadHome();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your home feed. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openTab(int index) => StudentShell.of(context)?.goToTab(index);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: SafeArea(
          child: RefreshIndicator(
            color: _blue,
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
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(color: _blue)),
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
            style: const TextStyle(color: Color(0xFFC0392B), height: 1.45),
          ),
        ],
      );
    }

    final snapshot = _snapshot!;
    final first = firstNameFrom(snapshot.user.displayName);
    final greeting = localGreeting();
    final appName = AppConfig.instance.appName;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        _TopBar(
          appName: appName,
          unreadCount: snapshot.unreadCount,
          onSearch: () => showQuickSearchSheet(context),
          onAlerts: () => _openTab(3),
          onProfile: () => _openTab(4),
        ),
        const SizedBox(height: 16),
        _GreetingRow(
          greeting: '$greeting, $first! 👋',
          quote: '“Small steps every day lead to big results.”',
        ),
        const SizedBox(height: 16),
        _HeroBanner(
          onContinue: () {
            final item = snapshot.continueLearning;
            if (item != null) {
              Navigator.of(context).pushNamed(
                AppRoutes.courseDetail,
                arguments: CourseDetailArgs(
                  courseId: item.courseId,
                  title: item.title,
                ),
              );
            } else {
              _openTab(1);
            }
          },
        ),
        const SizedBox(height: 18),
        _QuickActions(
          onCourses: () => _openTab(1),
          onLectures: () =>
              Navigator.of(context).pushNamed(AppRoutes.lecturesList),
          onTests: () => _openTab(2),
          onCalendar: () =>
              Navigator.of(context).pushNamed(AppRoutes.calendar),
          onProgress: () => _openTab(1),
          onSaved: () =>
              Navigator.of(context).pushNamed(AppRoutes.catalog),
        ),
        const SizedBox(height: 18),
        _ContinueLearningCard(
          item: snapshot.continueLearning,
          onViewAll: () => _openTab(1),
          onResume: () {
            final item = snapshot.continueLearning;
            if (item == null) {
              _openTab(1);
              return;
            }
            Navigator.of(context).pushNamed(
              AppRoutes.courseDetail,
              arguments: CourseDetailArgs(
                courseId: item.courseId,
                title: item.title,
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        _ProgressCard(
          progress: snapshot.progressOrEmpty,
          onDetails: () => _openTab(1),
        ),
        const SizedBox(height: 14),
        _UpcomingScheduleCard(
          lectures: snapshot.upcomingLecturesOrEmpty.isNotEmpty
              ? snapshot.upcomingLecturesOrEmpty
              : [
                  if (snapshot.nextLecture != null) snapshot.nextLecture!,
                ],
          assessments: snapshot.dueAssessmentsOrEmpty,
          onViewAll: () {
            Navigator.of(context).pushNamed(AppRoutes.todayDetail);
          },
          onLectures: () =>
              Navigator.of(context).pushNamed(AppRoutes.lecturesList),
          onTests: () => _openTab(2),
        ),
        const SizedBox(height: 14),
        const _StreakCard(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.appName,
    required this.unreadCount,
    required this.onSearch,
    required this.onAlerts,
    required this.onProfile,
  });

  final String appName;
  final int unreadCount;
  final VoidCallback onSearch;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final badge = unreadCount > 99 ? '99+' : '$unreadCount';
    return Row(
      children: [
        const _PragyuMark(size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _HomeScreenState._ink,
                ),
              ),
              const Text(
                'Learn Practice Improve Succeed',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.4,
                  color: _HomeScreenState._muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Quick search',
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded, color: _HomeScreenState._ink),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Alerts',
              onPressed: onAlerts,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _HomeScreenState._ink,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        GestureDetector(
          onTap: onProfile,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  _HomeScreenState._blue,
                  _HomeScreenState._purple,
                ],
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _HomeScreenState._ink.withValues(alpha: 0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              appName.isNotEmpty ? appName[0].toUpperCase() : 'P',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({
    required this.greeting,
    required this.quote,
  });

  final String greeting;
  final String quote;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = _formatDateChip(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _HomeScreenState._ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                quote,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _HomeScreenState._muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 108,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: _HomeScreenState._blue,
              ),
              const SizedBox(height: 6),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _HomeScreenState._ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "Let's keep learning!",
                style: TextStyle(
                  fontSize: 9,
                  color: _HomeScreenState._muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDateChip(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  final weekday = weekdays[(value.weekday - 1).clamp(0, 6)];
  final month = months[(value.month - 1).clamp(0, 11)];
  return '$weekday, ${value.day} $month ${value.year}';
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFE8EEFF),
            Color(0xFFF0EBFF),
            Color(0xFFEAF4FF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _HomeScreenState._ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/home_hero.jpg',
              width: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          const Positioned(
            right: 12,
            top: 14,
            child: Text(
              'Dream\nPrepare\nAchieve',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                fontStyle: FontStyle.italic,
                color: Color(0xFF9AA3B5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 120, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KEEP GOING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: _HomeScreenState._purple,
                  ),
                ),
                const SizedBox(height: 6),
                const Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: _HomeScreenState._ink,
                    ),
                    children: [
                      TextSpan(text: 'A Brighter Future\nStarts '),
                      TextSpan(
                        text: 'With You',
                        style: TextStyle(color: _HomeScreenState._blue),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onContinue,
                      borderRadius: BorderRadius.circular(22),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _HomeScreenState._blue,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue Learning',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
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
          Positioned(
            right: 16,
            bottom: 12,
            child: Row(
              children: List.generate(4, (i) {
                return Container(
                  width: i == 0 ? 14 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? _HomeScreenState._blue
                        : const Color(0xFFD5DBE8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCourses,
    required this.onLectures,
    required this.onTests,
    required this.onCalendar,
    required this.onProgress,
    required this.onSaved,
  });

  final VoidCallback onCourses;
  final VoidCallback onLectures;
  final VoidCallback onTests;
  final VoidCallback onCalendar;
  final VoidCallback onProgress;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final items = <({
      String label,
      IconData icon,
      Color bg,
      Color fg,
      VoidCallback onTap,
    })>[
      (
        label: 'My Courses',
        icon: Icons.menu_book_rounded,
        bg: const Color(0xFFE8F0FF),
        fg: _HomeScreenState._blue,
        onTap: onCourses,
      ),
      (
        label: 'Live Lectures',
        icon: Icons.play_circle_fill_rounded,
        bg: const Color(0xFFE7F8EF),
        fg: _HomeScreenState._green,
        onTap: onLectures,
      ),
      (
        label: 'Practice Tests',
        icon: Icons.assignment_outlined,
        bg: const Color(0xFFF0EBFF),
        fg: _HomeScreenState._purple,
        onTap: onTests,
      ),
      (
        label: 'Calendar',
        icon: Icons.calendar_month_rounded,
        bg: const Color(0xFFFFF0E5),
        fg: const Color(0xFFE67E22),
        onTap: onCalendar,
      ),
      (
        label: 'My Progress',
        icon: Icons.bar_chart_rounded,
        bg: const Color(0xFFFFEAF2),
        fg: const Color(0xFFD94F8B),
        onTap: onProgress,
      ),
      (
        label: 'Catalog',
        icon: Icons.explore_rounded,
        bg: const Color(0xFFEAF4FF),
        fg: const Color(0xFF3D8BDB),
        onTap: onSaved,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return SizedBox(
              width: width,
              child: Material(
                color: item.bg,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        Icon(item.icon, color: item.fg, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _HomeScreenState._ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _HomeScreenState._ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _HomeScreenState._ink,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: _HomeScreenState._blue,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({
    required this.item,
    required this.onViewAll,
    required this.onResume,
  });

  final HomeContinueItem? item;
  final VoidCallback onViewAll;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final progress = (item?.progressPercent ?? 0).clamp(0, 100);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Continue Learning',
            actionLabel: 'View All →',
            onAction: onViewAll,
          ),
          const SizedBox(height: 10),
          if (item == null)
            const Text(
              'No active course yet. Browse Learn to get started.',
              style: TextStyle(color: _HomeScreenState._muted, height: 1.4),
            )
          else ...[
            Container(
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFDDE7FF), Color(0xFFEFE9FF)],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.account_balance_rounded,
                size: 40,
                color: _HomeScreenState._blue,
              ),
            ),
            const SizedBox(height: 10),
            if (item!.subjectTag != null && item!.subjectTag!.isNotEmpty)
              Text(
                item!.subjectTag!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _HomeScreenState._muted,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              item!.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _HomeScreenState._ink,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
                backgroundColor: const Color(0xFFE8EDF5),
                color: _HomeScreenState._green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$progress%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _HomeScreenState._green,
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onResume,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _HomeScreenState._green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Resume Lesson',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.onDetails,
  });

  final HomeProgressSummary progress;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final percent = progress.overallPercent.clamp(0, 100);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'My Progress',
            actionLabel: 'View Details →',
            onAction: onDetails,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFFE8EDF5),
                        color: _HomeScreenState._blue,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _HomeScreenState._ink,
                          ),
                        ),
                        const Text(
                          'Overall',
                          style: TextStyle(
                            fontSize: 10,
                            color: _HomeScreenState._muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _StatLine(
                      icon: Icons.menu_book_rounded,
                      color: _HomeScreenState._blue,
                      label: '${progress.coursesEnrolled} Courses Enrolled',
                    ),
                    const SizedBox(height: 8),
                    _StatLine(
                      icon: Icons.quiz_outlined,
                      color: _HomeScreenState._purple,
                      label: '${progress.testsAttempted} Tests Attempted',
                    ),
                    const SizedBox(height: 8),
                    _StatLine(
                      icon: Icons.emoji_events_outlined,
                      color: _HomeScreenState._green,
                      label: progress.averageScorePercent == null
                          ? 'Score coming soon'
                          : '${progress.averageScorePercent}% Average Score',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _HomeScreenState._ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpcomingScheduleCard extends StatelessWidget {
  const _UpcomingScheduleCard({
    required this.lectures,
    required this.assessments,
    required this.onViewAll,
    required this.onLectures,
    required this.onTests,
  });

  final List<HomeLecture> lectures;
  final List<HomeAssessment> assessments;
  final VoidCallback onViewAll;
  final VoidCallback onLectures;
  final VoidCallback onTests;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final lecture in lectures.take(2)) {
      rows.add(
        _ScheduleRow(
          icon: Icons.sensors_rounded,
          iconBg: lecture.isLiveNow
              ? const Color(0xFFFFE8E8)
              : const Color(0xFFE8F0FF),
          iconColor: lecture.isLiveNow
              ? const Color(0xFFE53935)
              : _HomeScreenState._blue,
          title: lecture.title,
          subtitle: lecture.isLiveNow
              ? 'Live now'
              : (lecture.startsAt == null
                  ? 'Upcoming class'
                  : _formatWhen(lecture.startsAt!)),
          badge: lecture.isLiveNow ? 'LIVE' : null,
          onTap: onLectures,
        ),
      );
    }
    for (final assessment in assessments.take(2)) {
      rows.add(
        _ScheduleRow(
          icon: Icons.assignment_outlined,
          iconBg: const Color(0xFFE7F8EF),
          iconColor: _HomeScreenState._green,
          title: assessment.title,
          subtitle: assessment.due?.label ?? 'Upcoming test',
          onTap: onTests,
        ),
      );
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Upcoming Schedule',
            actionLabel: 'View All →',
            onAction: onViewAll,
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text(
              'No upcoming classes or tests right now.',
              style: TextStyle(color: _HomeScreenState._muted, height: 1.4),
            )
          else
            ...rows,
        ],
      ),
    );
  }

  static String _formatWhen(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month} · $hour:$minute $suffix';
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFFAFBFE),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _HomeScreenState._ink,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _HomeScreenState._muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _HomeScreenState._muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday; // Mon=1 .. Sun=7
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFFE6A817)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Keep it up! You're on the right track. Consistency leads to success.",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: _HomeScreenState._ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFE67E22)),
              SizedBox(width: 6),
              Text(
                '7 Day Streak',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _HomeScreenState._ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = index + 1;
              final done = day <= today && day <= 5;
              final isToday = day == today;
              return Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? _HomeScreenState._green
                          : Colors.transparent,
                      border: Border.all(
                        color: done
                            ? _HomeScreenState._green
                            : (isToday
                                ? _HomeScreenState._blue
                                : const Color(0xFFD5DBE8)),
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.w500,
                      color: _HomeScreenState._muted,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PragyuMark extends StatelessWidget {
  const _PragyuMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 5,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  _HomeScreenState._blue,
                  _HomeScreenState._purple,
                ],
              ).createShader(bounds),
              child: Text(
                'P',
                style: TextStyle(
                  fontSize: size * 0.78,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: -2,
            child: Icon(
              Icons.school_rounded,
              size: size * 0.38,
              color: _HomeScreenState._ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inherited access so Home shortcuts can switch bottom tabs.
class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    this.initialIndex = 0,
    this.homeRepository,
    this.learnRepository,
    this.testsRepository,
  });

  final int initialIndex;
  final HomeGateway? homeRepository;
  final LearnGateway? learnRepository;
  final TestsGateway? testsRepository;

  static StudentShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<StudentShellState>();
  }

  @override
  State<StudentShell> createState() => StudentShellState();
}

class StudentShellState extends State<StudentShell> {
  late int _index = widget.initialIndex;
  final Set<int> _mountedTabs = <int>{};

  @override
  void initState() {
    super.initState();
    _mountedTabs.add(_index);
  }

  void goToTab(int index) {
    if (index < 0 || index > 4) return;
    setState(() {
      _index = index;
      _mountedTabs.add(index);
    });
  }

  Widget _tab(int index) {
    if (!_mountedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return HomeScreen(homeRepository: widget.homeRepository);
      case 1:
        return MyLearningScreen(learnRepository: widget.learnRepository);
      case 2:
        return TestsHubScreen(testsRepository: widget.testsRepository);
      case 3:
        return const FeaturePlaceholderScreen(
          title: 'Alerts',
          nextScreenId: 'S-50',
          message: 'Your notification inbox will live here.',
        );
      case 4:
        return const FeaturePlaceholderScreen(
          title: 'Me',
          nextScreenId: 'S-70',
          message: 'Profile and settings will live here.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(5, _tab);
    final unread = 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goToTab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F0FF),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF4A7DFF)),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Learn',
          ),
          const NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz_rounded),
            label: 'Tests',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
