import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/shell/feature_placeholder_screen.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/greeting.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/presentation/screens/my_learning_screen.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';

/// S-10 Home — Today: greeting, next class, due tests, alerts strip, shortcuts.
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
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
          SizedBox(height: 160),
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

    final snapshot = _snapshot!;
    final first = firstNameFrom(snapshot.user.displayName);
    final greeting = localGreeting();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '$greeting, $first',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Quick search',
              onPressed: () => showQuickSearchSheet(context),
              icon: const Icon(Icons.search_rounded, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Here’s what’s next today.',
          style: TextStyle(fontSize: 15, color: AppColors.muted),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.todayDetail);
            },
            child: const Text('See today’s schedule'),
          ),
        ),
        if (snapshot.unreadCount > 0) ...[
          const SizedBox(height: 16),
          _UnreadStrip(count: snapshot.unreadCount),
        ],
        if (snapshot.nextLecture != null) ...[
          const SizedBox(height: 20),
          _LiveCard(
            lecture: snapshot.nextLecture!,
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.lecturesList);
            },
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'Due tests',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (snapshot.dueAssessments.isEmpty)
          const _EmptyHint(text: 'No upcoming tests right now.')
        else
          ...snapshot.dueAssessments.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DueTestTile(assessment: item),
            ),
          ),
        const SizedBox(height: 22),
        const Text(
          'Shortcuts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ShortcutChip(
              label: 'Learn',
              icon: Icons.menu_book_rounded,
              onTap: () => _openTab(context, 1),
            ),
            _ShortcutChip(
              label: 'Lectures',
              icon: Icons.sensors_rounded,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.lecturesList);
              },
            ),
            _ShortcutChip(
              label: 'Tests',
              icon: Icons.quiz_outlined,
              onTap: () => _openTab(context, 2),
            ),
            _ShortcutChip(
              label: 'Alerts',
              icon: Icons.notifications_none_rounded,
              onTap: () => _openTab(context, 3),
            ),
            _ShortcutChip(
              label: 'Me',
              icon: Icons.person_outline_rounded,
              onTap: () => _openTab(context, 4),
            ),
          ],
        ),
      ],
    );
  }

  void _openTab(BuildContext context, int index) {
    StudentShell.of(context)?.goToTab(index);
  }
}

class _UnreadStrip extends StatelessWidget {
  const _UnreadStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Material(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => StudentShell.of(context)?.goToTab(3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Unread alerts waiting for you',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.lecture,
    required this.onTap,
  });

  final HomeLecture lecture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final live = lecture.isLiveNow;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: live
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : AppColors.brandSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                live ? 'Live now' : 'Next class',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: live ? AppColors.accent : AppColors.muted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lecture.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if ((lecture.subjectName ?? lecture.courseName) != null) ...[
                const SizedBox(height: 4),
                Text(
                  [lecture.subjectName, lecture.courseName]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
              if (!live && lecture.startsAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatStarts(lecture.startsAt!),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatStarts(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return 'Starts ${local.day}/${local.month} · $hour:$minute $suffix';
  }
}

class _DueTestTile extends StatelessWidget {
  const _DueTestTile({required this.assessment});

  final HomeAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => StudentShell.of(context)?.goToTab(2),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
                      assessment.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (assessment.due?.label != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        assessment.due!.label!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted, height: 1.4),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 104,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brandSoft),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.brand),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
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
  });

  final int initialIndex;
  final HomeGateway? homeRepository;
  final LearnGateway? learnRepository;

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
        return const FeaturePlaceholderScreen(
          title: 'Tests',
          nextScreenId: 'S-40',
          message: 'Assessments and practice will live here.',
        );
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

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz_rounded),
            label: 'Tests',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
