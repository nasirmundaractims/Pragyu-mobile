import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/domain/greeting.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';

/// S-20 My learning — Learn tab redesigned from Pragyu Learn reference.
class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({
    super.key,
    this.learnRepository,
    this.sessionService,
    this.alertsRepository,
  });

  final LearnGateway? learnRepository;
  final SessionService? sessionService;
  final AlertsGateway? alertsRepository;

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

enum _LearnTab { myCourses, explore, subjects, studyMaterial }

enum _CourseFilter { all, active, completed }

class _MyLearningScreenState extends State<MyLearningScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _green = Color(0xFF22A06B);
  static const _pageBg = Color(0xFFF8FAFD);

  late final LearnGateway _learn =
      widget.learnRepository ?? LearnRepository();
  late final SessionService _session =
      widget.sessionService ?? SessionService();
  late final AlertsGateway _alerts =
      widget.alertsRepository ?? AlertsRepository();

  TextEditingController? _searchController;
  final _coursesKey = GlobalKey();
  final _subjectsKey = GlobalKey();
  final _recommendedKey = GlobalKey();

  bool _loading = true;
  String? _error;
  MyLearningSnapshot? _snapshot;
  AuthUser? _user;
  int _unread = 0;
  _LearnTab _tab = _LearnTab.myCourses;
  _CourseFilter _filter = _CourseFilter.all;

  TextEditingController get _search {
    final existing = _searchController;
    if (existing != null) return existing;
    final created = TextEditingController();
    created.addListener(_onSearchChanged);
    _searchController = created;
    return created;
  }

  String get _query => _searchController?.text ?? '';

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _search; // ensure controller exists for this State instance
    _load();
    _loadSessionChrome();
  }

  @override
  void dispose() {
    final controller = _searchController;
    if (controller != null) {
      controller.removeListener(_onSearchChanged);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _learn.loadMyLearning();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your courses. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _loadSessionChrome() async {
    try {
      final session = await _session.read();
      final unread = await _alerts.unreadCount();
      if (!mounted) return;
      setState(() {
        _user = session?.cachedUser;
        _unread = unread < 0 ? 0 : unread;
      });
    } catch (_) {
      // Chrome is optional — Learn still works without session chrome.
    }
  }

  void _openTab(int index) => StudentShell.of(context)?.goToTab(index);

  void _openCourse(LearningCourse course) {
    Navigator.of(context).pushNamed(
      AppRoutes.courseDetail,
      arguments: CourseDetailArgs(
        courseId: course.courseId,
        title: course.title,
        programName: course.programName,
        batchName: course.batchName,
      ),
    );
  }

  void _onTabSelected(_LearnTab tab) {
    switch (tab) {
      case _LearnTab.myCourses:
        setState(() => _tab = tab);
        _scrollTo(_coursesKey);
      case _LearnTab.subjects:
        setState(() => _tab = tab);
        _scrollTo(_subjectsKey);
      case _LearnTab.explore:
        Navigator.of(context).pushNamed(AppRoutes.catalog);
      case _LearnTab.studyMaterial:
        Navigator.of(context).pushNamed(AppRoutes.studyMaterials);
    }
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _openFilters() async {
    final selected = await showModalBottomSheet<_CourseFilter>(
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
                  'Filter courses',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                ..._CourseFilter.values.map((value) {
                  final label = switch (value) {
                    _CourseFilter.all => 'All courses',
                    _CourseFilter.active => 'Active',
                    _CourseFilter.completed => 'Completed',
                  };
                  final selected = _filter == value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: _blue)
                        : null,
                    onTap: () => Navigator.pop(context, value),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _filter = selected);
  }

  List<LearningCourse> _visibleCourses(List<LearningCourse> courses) {
    final q = _query.trim().toLowerCase();
    return courses.where((course) {
      final matchesFilter = switch (_filter) {
        _CourseFilter.all => true,
        _CourseFilter.active => course.isActive,
        _CourseFilter.completed =>
          !course.isActive ||
              (course.status ?? '').toLowerCase().contains('complete'),
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      final haystack = [
        course.title,
        course.programName ?? '',
        course.batchName ?? '',
        course.subtitle,
        course.statusLabel,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  String get _filterLabel => switch (_filter) {
        _CourseFilter.all => 'Filters',
        _CourseFilter.active => 'Active',
        _CourseFilter.completed => 'Completed',
      };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            const Positioned.fill(child: _SoftBlobsBackground()),
            SafeArea(
              child: RefreshIndicator(
                color: _blue,
                onRefresh: () async {
                  await Future.wait([_load(), _loadSessionChrome()]);
                },
                child: _buildBody(),
              ),
            ),
          ],
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
    final courses = _visibleCourses(snapshot.courses);
    final recommended = _visibleCourses(
      snapshot.courses.length > 1
          ? snapshot.courses.skip(1).take(6).toList()
          : snapshot.courses.take(3).toList(),
    );
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 360;
    final short = size.height < 700;
    final padH = narrow ? 14.0 : 18.0;
    final initials = initialsFromNames(
      firstName: _user?.firstName,
      lastName: _user?.lastName,
      fallbackDisplayName: _user?.displayName,
    );
    final query = _query.trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padH, 8, padH, 28),
      children: [
        _TopBar(
          unreadCount: _unread,
          initials: initials,
          onSearch: () => showQuickSearchSheet(context),
          onAlerts: () => _openTab(3),
          onProfile: () => _openTab(4),
        ),
        SizedBox(height: short ? 12 : 16),
        _LearnHero(
          narrow: narrow,
          short: short,
          script: const _KnowledgeScript(),
        ),
        SizedBox(height: short ? 12 : 14),
        _SearchFilterRow(
          controller: _search,
          onChanged: (_) {},
          onClear: query.isEmpty
              ? null
              : () {
                  _search.clear();
                  setState(() {});
                },
          onSubmit: () {
            // Keep focus on local course filtering; empty query opens global search.
            if (_query.trim().isEmpty) {
              showQuickSearchSheet(context);
            } else {
              setState(() {});
              _scrollTo(_coursesKey);
            }
          },
          onFilters: _openFilters,
          filterActive: _filter != _CourseFilter.all,
          filterLabel: _filterLabel,
        ),
        const SizedBox(height: 14),
        _LearnTabs(
          selected: _tab,
          onSelected: _onTabSelected,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFC0392B), height: 1.4),
          ),
        ],
        SizedBox(height: short ? 16 : 20),
        if (snapshot.isEmpty)
          _EmptyState(
            onBrowse: () =>
                Navigator.of(context).pushNamed(AppRoutes.catalog),
            onLectures: () =>
                Navigator.of(context).pushNamed(AppRoutes.lecturesList),
          )
        else
          KeyedSubtree(
            key: _coursesKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: 'My Courses',
                  onSeeAll: () =>
                      Navigator.of(context).pushNamed(AppRoutes.catalog),
                ),
                const SizedBox(height: 12),
                if (courses.isEmpty)
                  _InlineEmpty(
                    message: query.isEmpty && _filter == _CourseFilter.all
                        ? 'No courses to show.'
                        : 'No courses match your search or filters.',
                  )
                else
                  ...courses.map(
                    (course) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CourseCard(
                        course: course,
                        narrow: narrow,
                        onTap: () => _openCourse(course),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(height: short ? 16 : 22),
        KeyedSubtree(
          key: _subjectsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                title: 'Explore Subjects',
                onSeeAll: () =>
                    Navigator.of(context).pushNamed(AppRoutes.catalog),
              ),
              const SizedBox(height: 12),
              _SubjectsGrid(
                query: query,
                onSubject: (subject) {
                  _search
                    ..text = subject.name
                    ..selection = TextSelection.collapsed(
                      offset: subject.name.length,
                    );
                  setState(() {});
                  _scrollTo(_coursesKey);
                },
              ),
            ],
          ),
        ),
        SizedBox(height: short ? 16 : 22),
        KeyedSubtree(
          key: _recommendedKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                title: 'Recommended for You',
                onSeeAll: () => Navigator.of(context)
                    .pushNamed(AppRoutes.recommendations),
              ),
              const SizedBox(height: 12),
              if (recommended.isEmpty)
                const _InlineEmpty(
                  message: 'Recommendations will appear as you learn.',
                )
              else
                SizedBox(
                  height: narrow ? 118 : 126,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recommended.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final course = recommended[index];
                      return _RecommendedCard(
                        course: course,
                        onTap: () => _openCourse(course),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
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
  });

  final int unreadCount;
  final String initials;
  final VoidCallback onSearch;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final badge = unreadCount > 99 ? '99+' : '$unreadCount';

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
                  color: _MyLearningScreenState._muted,
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
          icon: const Icon(
            Icons.search_rounded,
            color: _MyLearningScreenState._ink,
          ),
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
                color: _MyLearningScreenState._ink,
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
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _MyLearningScreenState._ink,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LearnHero extends StatelessWidget {
  const _LearnHero({
    required this.narrow,
    required this.short,
    required this.script,
  });

  final bool narrow;
  final bool short;
  final Widget script;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learn',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: narrow ? 28 : 32,
            fontWeight: FontWeight.w800,
            color: _MyLearningScreenState._ink,
            height: 1.1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore courses, subjects and learning materials designed for your success.',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: short ? 13 : 14,
            height: 1.4,
            color: _MyLearningScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    // Reference layout: title/subtitle on the left, cursive flourish on the
    // right so it sits visually above the Filters button.
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: script),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: copy),
        const SizedBox(width: 8),
        Flexible(
          flex: 5,
          child: Align(
            alignment: Alignment.topRight,
            child: script,
          ),
        ),
      ],
    );
  }
}

class _KnowledgeScript extends StatelessWidget {
  const _KnowledgeScript();

  static const _asset = 'assets/images/learn/knowledge_builds_script.png';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = width < 360 ? 98.0 : width < 420 ? 110.0 : 122.0;

    Widget scriptImage({double opacity = 1}) {
      return Opacity(
        opacity: opacity,
        child: Image.asset(
          _asset,
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, error, stackTrace) {
            return Text(
              'Knowledge Builds\nBetter You',
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontFamily: AppTheme.scriptFontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: _MyLearningScreenState._ink,
              ),
            );
          },
        ),
      );
    }

    return Semantics(
      label: 'Knowledge Builds Better You',
      child: Transform.rotate(
        angle: -0.14,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: 46),
          child: AspectRatio(
            aspectRatio: 950 / 460,
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                // Slight offset copies make the calligraphy read bolder.
                Transform.translate(
                  offset: const Offset(0.6, 0),
                  child: scriptImage(opacity: 0.85),
                ),
                Transform.translate(
                  offset: const Offset(0, 0.5),
                  child: scriptImage(opacity: 0.85),
                ),
                scriptImage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchFilterRow extends StatelessWidget {
  const _SearchFilterRow({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    required this.onFilters,
    required this.filterActive,
    required this.filterLabel,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onFilters;
  final bool filterActive;
  final String filterLabel;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFilters = constraints.maxWidth < 340;
        final field = Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: _MyLearningScreenState._ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search for courses, subjects, chapters...',
              hintStyle: const TextStyle(
                color: _MyLearningScreenState._muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _MyLearningScreenState._muted,
              ),
              suffixIcon: onClear == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _MyLearningScreenState._muted,
                      ),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD9E2EF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD9E2EF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: _MyLearningScreenState._blue,
                  width: 1.4,
                ),
              ),
            ),
          ),
        );

        final filters = Material(
          color: filterActive
              ? _MyLearningScreenState._blue
              : _MyLearningScreenState._blueSoft,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onFilters,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: stackFilters ? 14 : 12,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: filterActive
                        ? Colors.white
                        : _MyLearningScreenState._ink,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filterLabel,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: filterActive
                          ? Colors.white
                          : _MyLearningScreenState._ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (stackFilters) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [field]),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: filters),
            ],
          );
        }

        return Row(
          children: [
            field,
            const SizedBox(width: 10),
            filters,
          ],
        );
      },
    );
  }
}

class _LearnTabs extends StatelessWidget {
  const _LearnTabs({
    required this.selected,
    required this.onSelected,
  });

  final _LearnTab selected;
  final ValueChanged<_LearnTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <(_LearnTab, String)>[
      (_LearnTab.myCourses, 'My Courses'),
      (_LearnTab.explore, 'Explore'),
      (_LearnTab.subjects, 'Subjects'),
      (_LearnTab.studyMaterial, 'Study Material'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _TabPill(
              label: item.$2,
              active: selected == item.$1,
              onTap: () => onSelected(item.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? _MyLearningScreenState._blue
          : const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : _MyLearningScreenState._ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
  });

  final String title;
  final VoidCallback onSeeAll;

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
              color: _MyLearningScreenState._ink,
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: _MyLearningScreenState._blue,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See All',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.narrow,
    required this.onTap,
  });

  final LearningCourse course;
  final bool narrow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = course.subtitle;
    final progress = (course.progressPercent ?? 0).clamp(0, 100);
    final inProgress = course.isActive && progress < 100;

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.title,
          softWrap: true,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _MyLearningScreenState._ink,
            height: 1.25,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: _MyLearningScreenState._muted,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusChip(label: course.statusLabel, active: course.isActive),
            Text(
              '$progress%',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w800,
                color: _MyLearningScreenState._green,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 7,
            backgroundColor: const Color(0xFFE8EEF5),
            color: _MyLearningScreenState._green,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            _MetaChip(
              icon: Icons.menu_book_outlined,
              label: course.programName?.trim().isNotEmpty == true
                  ? course.programName!.trim()
                  : 'Course',
            ),
            if (course.batchName?.trim().isNotEmpty == true)
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: course.batchName!.trim(),
              ),
          ],
        ),
      ],
    );

    final thumb = _CourseThumb(inProgress: inProgress);

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      shadowColor: const Color(0x1A1A2B4C),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14001A3D),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackCta = narrow || constraints.maxWidth < 420;
                final cta = _ContinueButton(
                  compact: stackCta,
                  onPressed: onTap,
                );

                final top = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumb,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                );

                if (stackCta) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      top,
                      const SizedBox(height: 12),
                      cta,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    thumb,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 10),
                    cta,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseThumb extends StatelessWidget {
  const _CourseThumb({required this.inProgress});

  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2F7BFF),
                    Color(0xFF6B8CFF),
                    Color(0xFFB8C9FF),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          if (inProgress)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A2B4C),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        size: 11, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'In Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
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
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.onPressed,
    required this.compact,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _MyLearningScreenState._blue,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 12,
            vertical: compact ? 12 : 14,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  compact ? 'Continue →' : 'Continue Learning →',
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _MyLearningScreenState._muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              color: _MyLearningScreenState._muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE6F5EE) : const Color(0xFFE8EEF6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active
              ? _MyLearningScreenState._green
              : _MyLearningScreenState._muted,
        ),
      ),
    );
  }
}

class _SubjectSpec {
  const _SubjectSpec({
    required this.name,
    required this.icon,
    required this.background,
    required this.accent,
    required this.hint,
  });

  final String name;
  final IconData icon;
  final Color background;
  final Color accent;
  final String hint;
}

class _SubjectsGrid extends StatelessWidget {
  const _SubjectsGrid({
    required this.onSubject,
    this.query = '',
  });

  final ValueChanged<_SubjectSpec> onSubject;
  final String query;

  static const subjects = <_SubjectSpec>[
    _SubjectSpec(
      name: 'Polity',
      icon: Icons.account_balance_rounded,
      background: Color(0xFFF0E8FF),
      accent: Color(0xFF7B5CFF),
      hint: 'Explore topics',
    ),
    _SubjectSpec(
      name: 'History',
      icon: Icons.menu_book_rounded,
      background: Color(0xFFFFF0E4),
      accent: Color(0xFFE67E22),
      hint: 'Explore topics',
    ),
    _SubjectSpec(
      name: 'Geography',
      icon: Icons.public_rounded,
      background: Color(0xFFE6F7F4),
      accent: Color(0xFF1ABC9C),
      hint: 'Explore topics',
    ),
    _SubjectSpec(
      name: 'Economy',
      icon: Icons.bar_chart_rounded,
      background: Color(0xFFE8F1FF),
      accent: Color(0xFF2F7BFF),
      hint: 'Explore topics',
    ),
    _SubjectSpec(
      name: 'Environment',
      icon: Icons.eco_rounded,
      background: Color(0xFFE8F8EE),
      accent: Color(0xFF27AE60),
      hint: 'Explore topics',
    ),
    _SubjectSpec(
      name: 'Science & Tech',
      icon: Icons.science_rounded,
      background: Color(0xFFFFEAF2),
      accent: Color(0xFFE84393),
      hint: 'Explore topics',
    ),
    _SubjectSpec(
      name: 'Ethics',
      icon: Icons.groups_rounded,
      background: Color(0xFFFFF8E6),
      accent: Color(0xFFF1C40F),
      hint: 'Explore topics',
    ),
    _SubjectSpec(
      name: 'Current Affairs',
      icon: Icons.article_rounded,
      background: Color(0xFFEDE7F6),
      accent: Color(0xFF6C5CE7),
      hint: 'Explore topics',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? subjects
        : subjects
            .where((subject) => subject.name.toLowerCase().contains(q))
            .toList();

    if (visible.isEmpty) {
      return const _InlineEmpty(
        message: 'No subjects match your search.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 520
            ? 3
            : constraints.maxWidth >= 300
                ? 2
                : 1;
        final gap = 10.0;
        final tileW =
            (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final subject in visible)
              SizedBox(
                width: tileW,
                child: _SubjectTile(
                  subject: subject,
                  onTap: () => onSubject(subject),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.onTap,
  });

  final _SubjectSpec subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: subject.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(subject.icon, color: subject.accent, size: 26),
              const SizedBox(height: 10),
              Text(
                subject.name,
                softWrap: true,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _MyLearningScreenState._ink,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.hint,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: subject.accent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: subject.accent,
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

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.course,
    required this.onTap,
  });

  final LearningCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = course.subtitle.isNotEmpty
        ? course.subtitle
        : (course.isActive ? 'Continue where you left off' : 'Review & revise');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12001A3D),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4C7DFF), Color(0xFF9BB6FF)],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _MyLearningScreenState._ink,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: _MyLearningScreenState._muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 13,
                            color: _MyLearningScreenState._muted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              course.statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _MyLearningScreenState._muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: _MyLearningScreenState._blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onBrowse,
    required this.onLectures,
  });

  final VoidCallback onBrowse;
  final VoidCallback onLectures;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12001A3D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: _MyLearningScreenState._blueSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_outlined,
              size: 32,
              color: _MyLearningScreenState._blue,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No enrolled courses yet',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _MyLearningScreenState._ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Live lectures can still appear on Home when your institute schedules them. Enroll in a course to unlock modules and lessons here.',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: _MyLearningScreenState._muted,
              height: 1.45,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                backgroundColor: _MyLearningScreenState._blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Browse catalog'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onLectures,
            child: const Text('Open lectures'),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Text(
        message,
        softWrap: true,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: _MyLearningScreenState._muted,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SoftBlobsBackground extends StatelessWidget {
  const _SoftBlobsBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BlobPainter());
  }
}

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final top = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x55C9B8FF), Color(0x00C9B8FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.7, size.height * 0.28));
    canvas.drawCircle(
      Offset(size.width * 0.92, -size.height * 0.02),
      size.width * 0.42,
      top,
    );

    final mid = Paint()
      ..color = const Color(0x33A8C8FF);
    canvas.drawCircle(
      Offset(-size.width * 0.12, size.height * 0.18),
      size.width * 0.34,
      mid,
    );

    final bottom = Paint()
      ..color = const Color(0x28B7A6FF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.92),
        width: size.width * 0.7,
        height: size.height * 0.22,
      ),
      bottom,
    );

    // Soft highlight near mid-right.
    final accent = Paint()
      ..color = const Color(0x22D6E6FF);
    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 0.55),
      size.width * 0.28,
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
