import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/greeting.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/learn/presentation/screens/my_learning_screen.dart';
import 'package:student_mobile/features/me/data/me_repository.dart';
import 'package:student_mobile/features/me/presentation/screens/me_screen.dart';
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
  static const _blue = Color(0xFF2F7BFF);
  static const _green = Color(0xFF22A06B);
  static const _heroAsset = 'assets/images/auth/hero_home.png';

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

  static List<HomeLecture> _scheduleLectures(HomeSnapshot snapshot) {
    final upcoming = snapshot.upcomingLectures;
    if (upcoming.isNotEmpty) return upcoming;
    final next = snapshot.nextLecture;
    if (next == null) return const <HomeLecture>[];
    return <HomeLecture>[next];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
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
    final first = greetingFirstName(
      firstName: snapshot.user.firstName,
      profileDisplayName: snapshot.profileDisplayName,
      fallbackDisplayName: snapshot.user.displayName,
    );
    final greeting = localGreeting();
    final initials = initialsFromNames(
      firstName: snapshot.user.firstName,
      lastName: snapshot.user.lastName,
      profileDisplayName: snapshot.profileDisplayName,
      fallbackDisplayName: snapshot.user.displayName,
    );
    final progress = snapshot.progressOrEmpty;
    final continueItem = snapshot.continueLearning;
    final lectures = _scheduleLectures(snapshot);
    final assessments = snapshot.dueAssessmentsOrEmpty;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 360;
    final short = size.height < 700;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        narrow ? 14 : 18,
        8,
        narrow ? 14 : 18,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(
            unreadCount: snapshot.unreadCount,
            initials: initials,
            avatarUrl: snapshot.avatarUrl,
            onSearch: () => showQuickSearchSheet(context),
            onAlerts: () => _openTab(3),
            onProfile: () => _openTab(4),
          ),
          SizedBox(height: short ? 12 : 16),
          _GreetingHero(
            greeting: '$greeting, $first! 👋',
            subtitle:
                'Stay consistent. A brighter you is closer than you think.',
            narrow: narrow,
            short: short,
          ),
          SizedBox(height: short ? 14 : 18),
          _GoalCard(
            title: continueItem?.subjectTag?.trim().isNotEmpty == true
                ? continueItem!.subjectTag!.trim()
                : (progress.coursesEnrolled > 0
                    ? '${progress.coursesEnrolled} courses enrolled'
                    : 'Your learning plan'),
            percent: progress.overallPercent,
            onViewPlan: () {
              Navigator.of(context).pushNamed(AppRoutes.todayDetail);
            },
          ),
          SizedBox(height: short ? 16 : 20),
          _SectionHeader(
            title: "Today's Plan",
            actionLabel: 'See All',
            onAction: () {
              Navigator.of(context).pushNamed(AppRoutes.todayDetail);
            },
          ),
          const SizedBox(height: 12),
          _TodaysPlanRow(
            continueTag: continueItem?.subjectTag,
            dueLabel: assessments.isNotEmpty ? assessments.first.title : null,
            lectureLabel:
                lectures.isNotEmpty ? lectures.first.subjectName : null,
            onStudy: () => _openTab(1),
            onPractice: () => _openTab(2),
            onAiMentor: () =>
                Navigator.of(context).pushNamed(AppRoutes.aiMentor),
            onCatalog: () =>
                Navigator.of(context).pushNamed(AppRoutes.catalog),
          ),
          SizedBox(height: short ? 16 : 20),
          _SectionHeader(
            title: 'Continue Learning',
            actionLabel: 'See All',
            onAction: () => _openTab(1),
          ),
          const SizedBox(height: 12),
          _ContinueLearningCard(
            item: continueItem,
            onResume: () {
              if (continueItem == null) {
                _openTab(1);
                return;
              }
              Navigator.of(context).pushNamed(
                AppRoutes.courseDetail,
                arguments: CourseDetailArgs(
                  courseId: continueItem.courseId,
                  title: continueItem.title,
                ),
              );
            },
            onEmpty: () => _openTab(1),
          ),
          SizedBox(height: short ? 16 : 20),
          _SectionHeader(
            title: 'Upcoming Schedule',
            actionLabel: 'See All',
            onAction: () {
              Navigator.of(context).pushNamed(AppRoutes.todayDetail);
            },
          ),
          const SizedBox(height: 12),
          _UpcomingScheduleCard(
            lectures: lectures,
            assessments: assessments,
            onLecture: () =>
                Navigator.of(context).pushNamed(AppRoutes.lecturesList),
            onAssessment: () => _openTab(2),
          ),
          SizedBox(height: short ? 16 : 20),
          const _MotivationBanner(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.unreadCount,
    required this.initials,
    required this.onSearch,
    required this.onAlerts,
    required this.onProfile,
    this.avatarUrl,
  });

  final int unreadCount;
  final String initials;
  final String? avatarUrl;
  final VoidCallback onSearch;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final badge = unreadCount > 99 ? '99+' : '$unreadCount';
    final photo = avatarUrl?.trim();
    final hasPhoto = photo != null && photo.isNotEmpty;

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PragyuLogo(height: 34),
              SizedBox(height: 4),
              Text(
                'Learn • Practice • Grow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
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
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.search_rounded, color: _HomeScreenState._ink),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Alerts',
              onPressed: onAlerts,
              visualDensity: VisualDensity.compact,
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
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onProfile,
          child: ClipOval(
            child: Container(
              width: 36,
              height: 36,
              color: _HomeScreenState._ink,
              alignment: Alignment.center,
              child: hasPhoto
                  ? Image.network(
                      photo,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GreetingHero extends StatelessWidget {
  const _GreetingHero({
    required this.greeting,
    required this.subtitle,
    required this.narrow,
    required this.short,
  });

  final String greeting;
  final String subtitle;
  final bool narrow;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: narrow ? 22 : 26,
            fontWeight: FontWeight.w800,
            color: _HomeScreenState._ink,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: short ? 12.5 : 13.5,
            height: 1.4,
            color: _HomeScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final hero = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: narrow ? 110 : 132,
        maxHeight: short ? 100 : 124,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          _HomeScreenState._heroAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Student illustration',
          errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          copy,
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: hero),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: copy),
        const SizedBox(width: 8),
        hero,
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.title,
    required this.percent,
    required this.onViewPlan,
  });

  final String title;
  final int percent;
  final VoidCallback onViewPlan;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2F7BFF),
            Color(0xFF7C5CFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _HomeScreenState._blue.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Goal',
                      style: TextStyle(
                        color: Color(0xFFE8F0FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onViewPlan,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    'View Plan →',
                    style: TextStyle(
                      color: _HomeScreenState._blue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: clamped / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF7DFFB3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$clamped%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Keep going! You're on the right path.",
            softWrap: true,
            style: TextStyle(
              color: Color(0xFFE8F0FF),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _HomeScreenState._ink,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: _HomeScreenState._muted,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '$actionLabel >',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodaysPlanRow extends StatelessWidget {
  const _TodaysPlanRow({
    required this.onStudy,
    required this.onPractice,
    required this.onAiMentor,
    required this.onCatalog,
    this.continueTag,
    this.dueLabel,
    this.lectureLabel,
  });

  final VoidCallback onStudy;
  final VoidCallback onPractice;
  final VoidCallback onAiMentor;
  final VoidCallback onCatalog;
  final String? continueTag;
  final String? dueLabel;
  final String? lectureLabel;

  @override
  Widget build(BuildContext context) {
    final items = [
      _PlanItem(
        label: 'Study',
        subtitle: continueTag?.trim().isNotEmpty == true
            ? continueTag!
            : 'My Courses',
        meta: 'Learn',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF7C5CFF),
        background: const Color(0xFFF3EEFF),
        onTap: onStudy,
      ),
      _PlanItem(
        label: 'Practice',
        subtitle: dueLabel?.trim().isNotEmpty == true
            ? 'Due assessment'
            : 'Practice Tests',
        meta: 'Tests',
        icon: Icons.track_changes_rounded,
        color: const Color(0xFF1DBA8A),
        background: const Color(0xFFE8FBF4),
        onTap: onPractice,
      ),
      _PlanItem(
        label: 'AI Mentor',
        subtitle: lectureLabel?.trim().isNotEmpty == true
            ? lectureLabel!
            : 'Ask anything',
        meta: 'Mentor',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFFF08A3C),
        background: const Color(0xFFFFF2E8),
        onTap: onAiMentor,
      ),
      _PlanItem(
        label: 'Catalog',
        subtitle: 'Explore more',
        meta: 'Browse',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF2F7BFF),
        background: const Color(0xFFEEF5FF),
        onTap: onCatalog,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideEnoughForTwo = constraints.maxWidth >= 300;
        if (!wideEnoughForTwo) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                SizedBox(height: 140, child: items[i]),
              ],
            ],
          );
        }

        final cardWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                height: 140,
                child: item,
              ),
          ],
        );
      },
    );
  }
}

class _PlanItem extends StatelessWidget {
  const _PlanItem({
    required this.label,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String meta;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  subtitle,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _HomeScreenState._ink,
                    height: 1.25,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Colors.white,
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

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({
    required this.item,
    required this.onResume,
    required this.onEmpty,
  });

  final HomeContinueItem? item;
  final VoidCallback onResume;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return _EmptyCard(
        message: 'No course in progress yet. Browse your learning.',
        actionLabel: 'Go to Learn',
        onAction: onEmpty,
      );
    }

    final percent = item!.progressPercent.clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: [
          BoxShadow(
            color: _HomeScreenState._ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2F7BFF), Color(0xFF7C5CFF)],
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'In Progress',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _HomeScreenState._blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item!.title,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _HomeScreenState._ink,
                    height: 1.25,
                  ),
                ),
                if (item!.lessonTitle?.trim().isNotEmpty == true ||
                    item!.subjectTag?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (item!.subjectTag?.trim().isNotEmpty == true)
                        item!.subjectTag!.trim(),
                      if (item!.lessonTitle?.trim().isNotEmpty == true)
                        item!.lessonTitle!.trim(),
                    ].join(' • '),
                    softWrap: true,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _HomeScreenState._muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE8EEF8),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _HomeScreenState._green,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _HomeScreenState._green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: _HomeScreenState._blue,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onResume,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Text(
                          'Continue →',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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

class _UpcomingScheduleCard extends StatelessWidget {
  const _UpcomingScheduleCard({
    required this.lectures,
    required this.assessments,
    required this.onLecture,
    required this.onAssessment,
  });

  final List<HomeLecture> lectures;
  final List<HomeAssessment> assessments;
  final VoidCallback onLecture;
  final VoidCallback onAssessment;

  @override
  Widget build(BuildContext context) {
    if (lectures.isEmpty && assessments.isEmpty) {
      return const _EmptyCard(
        message: 'No upcoming classes or tests right now.',
      );
    }

    return Column(
      children: [
        for (final lecture in lectures.take(2)) ...[
          _LectureTile(lecture: lecture, onTap: onLecture),
          const SizedBox(height: 10),
        ],
        for (final assessment in assessments.take(2)) ...[
          _AssessmentTile(assessment: assessment, onTap: onAssessment),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LectureTile extends StatelessWidget {
  const _LectureTile({required this.lecture, required this.onTap});

  final HomeLecture lecture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final starts = lecture.startsAt;
    final dateLabel = starts == null
        ? 'Soon'
        : '${starts.day} ${_monthShort(starts.month)}';
    final timeLabel = starts == null ? 'Time TBA' : _formatTimeRange(starts);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FBF4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _HomeScreenState._green,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lecture.title,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _HomeScreenState._ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (lecture.subjectName?.trim().isNotEmpty == true)
                          lecture.subjectName!.trim(),
                        if (lecture.courseName?.trim().isNotEmpty == true)
                          lecture.courseName!.trim(),
                      ].where((e) => e.isNotEmpty).join(' • ').isEmpty
                          ? 'Live class'
                          : [
                              if (lecture.subjectName?.trim().isNotEmpty ==
                                  true)
                                lecture.subjectName!.trim(),
                              if (lecture.courseName?.trim().isNotEmpty == true)
                                lecture.courseName!.trim(),
                            ].join(' • '),
                      softWrap: true,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _HomeScreenState._muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _HomeScreenState._muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (lecture.isLiveNow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8E8),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Color(0xFFE53935),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Live',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                lecture.isLiveNow ? 'Join →' : 'Open →',
                style: const TextStyle(
                  color: _HomeScreenState._blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _monthShort(int month) {
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
    return months[(month - 1).clamp(0, 11)];
  }

  static String _formatTimeRange(DateTime start) {
    final end = start.add(const Duration(hours: 1));
    return '${_ampm(start)} - ${_ampm(end)}';
  }

  static String _ampm(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _AssessmentTile extends StatelessWidget {
  const _AssessmentTile({required this.assessment, required this.onTap});

  final HomeAssessment assessment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: Color(0xFFF08A3C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assessment.title,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _HomeScreenState._ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assessment.due?.label ?? 'Upcoming test',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _HomeScreenState._muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Open →',
                style: TextStyle(
                  color: _HomeScreenState._blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            softWrap: true,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: _HomeScreenState._muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: _HomeScreenState._blue,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MotivationBanner extends StatelessWidget {
  const _MotivationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0E8), Color(0xFFF3EEFF)],
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: Color(0xFFE0A800), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: _HomeScreenState._ink,
                ),
                children: [
                  TextSpan(
                    text: 'Small Steps Lead to Big Results! ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: 'Keep learning, keep practicing, keep growing.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
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
    this.alertsRepository,
    this.meRepository,
  });

  final int initialIndex;
  final HomeGateway? homeRepository;
  final LearnGateway? learnRepository;
  final TestsGateway? testsRepository;
  final AlertsGateway? alertsRepository;
  final MeGateway? meRepository;

  static StudentShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<StudentShellState>();
  }

  @override
  State<StudentShell> createState() => StudentShellState();
}

class StudentShellState extends State<StudentShell> {
  late int _index = widget.initialIndex;
  final Set<int> _mountedTabs = <int>{};
  late final AlertsGateway _alerts =
      widget.alertsRepository ?? AlertsRepository();
  int _alertsUnread = 0;

  @override
  void initState() {
    super.initState();
    _mountedTabs.add(_index);
    _refreshAlertsBadge();
  }

  void goToTab(int index) {
    if (index < 0 || index > 4) return;
    setState(() {
      _index = index;
      _mountedTabs.add(index);
    });
    if (index == 3) {
      _refreshAlertsBadge();
    }
  }

  void setAlertsUnread(int count) {
    if (_alertsUnread == count) return;
    setState(() => _alertsUnread = count < 0 ? 0 : count);
  }

  Future<void> _refreshAlertsBadge() async {
    try {
      final count = await _alerts.unreadCount();
      if (!mounted) return;
      setAlertsUnread(count);
    } catch (_) {}
  }

  Widget _tab(int index) {
    if (!_mountedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return HomeScreen(homeRepository: widget.homeRepository);
      case 1:
        return MyLearningScreen(
          key: const ValueKey('learn-screen-v3'),
          learnRepository: widget.learnRepository,
        );
      case 2:
        return TestsHubScreen(testsRepository: widget.testsRepository);
      case 3:
        return AlertsScreen(
          alertsRepository: widget.alertsRepository ?? _alerts,
          onUnreadChanged: setAlertsUnread,
        );
      case 4:
        return MeScreen(meRepository: widget.meRepository);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(5, _tab);
    final unread = _alertsUnread < 0 ? 0 : _alertsUnread;
    final badgeLabel = unread > 99 ? '99+' : '$unread';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }
      },
      child: Scaffold(
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
              selectedIcon:
                  Icon(Icons.home_rounded, color: Color(0xFF2F7BFF)),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Learn',
            ),
            const NavigationDestination(
              icon: Icon(Icons.track_changes_outlined),
              selectedIcon: Icon(
                Icons.track_changes_rounded,
                color: Color(0xFF2F7BFF),
              ),
              label: 'Practice',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(badgeLabel),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text(badgeLabel),
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}
