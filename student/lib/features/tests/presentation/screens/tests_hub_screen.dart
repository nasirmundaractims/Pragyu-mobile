import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/home/domain/greeting.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';

/// S-40 Tests / Practice hub — redesigned from the Pragyu Practice reference.
class TestsHubScreen extends StatefulWidget {
  const TestsHubScreen({
    super.key,
    this.testsRepository,
    this.sessionService,
    this.alertsRepository,
  });

  final TestsGateway? testsRepository;
  final SessionService? sessionService;
  final AlertsGateway? alertsRepository;

  @override
  State<TestsHubScreen> createState() => _TestsHubScreenState();
}

enum _PracticeMode { byTopic, mock, mixed, previousYear }

enum _ChipTone { blue, teal, orange, red }

class _TestsHubScreenState extends State<TestsHubScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _pageBg = Color(0xFFF8FAFD);
  static const _tealSoft = Color(0xFFE6F7F1);
  static const _orangeSoft = Color(0xFFFFF1E0);
  static const _redSoft = Color(0xFFFDECEC);
  static const _green = Color(0xFF22A06B);
  static const _greenSoft = Color(0xFFE8F8EF);

  late final TestsGateway _tests =
      widget.testsRepository ?? TestsRepository();
  late final SessionService _session =
      widget.sessionService ?? SessionService();
  late final AlertsGateway _alerts =
      widget.alertsRepository ?? AlertsRepository();

  final _modesKey = GlobalKey();

  bool _loading = true;
  String? _error;
  TestsSnapshot? _snapshot;
  TestsFilter _filter = TestsFilter.all;
  _PracticeMode _mode = _PracticeMode.mixed;
  String? _typeKey;
  String? _selectedId;
  AuthUser? _user;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSessionChrome();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _tests.loadTests();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _syncSelection(snapshot);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load tests. Pull to retry.';
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
    } catch (_) {}
  }

  void _syncSelection(TestsSnapshot snapshot) {
    final visible = _visibleItems(snapshot);
    if (visible.isEmpty) {
      _selectedId = null;
      return;
    }
    if (!visible.any((item) => item.id == _selectedId)) {
      _selectedId = visible.first.id;
    }
  }

  void _openTab(int index) => StudentShell.of(context)?.goToTab(index);

  void _openTest(TestListItem item) {
    Navigator.of(context).pushNamed(
      AppRoutes.assessmentDetail,
      arguments: AssessmentDetailArgs(
        assessmentId: item.id,
        title: item.title,
      ),
    );
  }

  List<TestListItem> _visibleItems(TestsSnapshot snapshot) {
    var items = snapshot.filtered(_filter);
    if (_typeKey != null && _typeKey!.isNotEmpty) {
      items = items
          .where((item) => item.typeLabel == _typeKey)
          .toList(growable: false);
    }
    switch (_mode) {
      case _PracticeMode.byTopic:
        items = items.where((item) => item.isPractice).toList(growable: false);
      case _PracticeMode.mock:
        items = items
            .where((item) => item.type == TestKind.exam)
            .toList(growable: false);
      case _PracticeMode.mixed:
        break;
      case _PracticeMode.previousYear:
        items = items
            .where(
              (item) =>
                  item.type == TestKind.exam || _looksLikePastYear(item.title),
            )
            .toList(growable: false);
    }
    return items;
  }

  static bool _looksLikePastYear(String title) {
    final lower = title.toLowerCase();
    return RegExp(r'\b(19|20)\d{2}\b').hasMatch(title) ||
        lower.contains('previous year') ||
        lower.contains('pyq');
  }

  List<String> _typeOptions(TestsSnapshot snapshot) {
    final labels = <String>{for (final item in snapshot.items) item.typeLabel};
    final sorted = labels.toList()..sort();
    return sorted;
  }

  TestListItem? _selectedItem(List<TestListItem> visible) {
    if (visible.isEmpty) return null;
    for (final item in visible) {
      if (item.id == _selectedId) return item;
    }
    return visible.first;
  }

  void _selectAdjacent(List<TestListItem> visible, int delta) {
    if (visible.isEmpty) return;
    final current = _selectedItem(visible);
    if (current == null) return;
    final index = visible.indexWhere((item) => item.id == current.id);
    if (index < 0) return;
    final next = (index + delta).clamp(0, visible.length - 1);
    setState(() => _selectedId = visible[next].id);
  }

  void _scrollToModes() {
    final target = _modesKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = initialsFromNames(
      firstName: _user?.firstName,
      lastName: _user?.lastName,
      fallbackDisplayName: _user?.displayName,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: RefreshIndicator(
            color: _blue,
            onRefresh: _load,
            child: _buildBody(initials),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String initials) {
    if (_loading && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
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
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 380;
    final short = size.height < 700;
    final visible = _visibleItems(snapshot);
    final selected = _selectedItem(visible);
    final typeOptions = _typeOptions(snapshot);
    final selectedIndex = selected == null
        ? -1
        : visible.indexWhere((e) => e.id == selected.id);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 20, 8, narrow ? 16 : 20, 28),
      children: [
        _TopBar(
          unreadCount: _unread,
          initials: initials,
          onSearch: () => showQuickSearchSheet(context),
          onAlerts: () =>
              Navigator.of(context).pushNamed(AppRoutes.alerts),
          onProfile: () => _openTab(4),
          onHistory: () =>
              Navigator.of(context).pushNamed(AppRoutes.pastResults),
        ),
        SizedBox(height: short ? 12 : 16),
        _PracticeHero(narrow: narrow, short: short),
        SizedBox(height: short ? 14 : 18),
        KeyedSubtree(
          key: _modesKey,
          child: _ModeRow(
            selected: _mode,
            narrow: narrow,
            onChanged: (mode) {
              setState(() {
                _mode = mode;
                _syncSelection(snapshot);
              });
            },
          ),
        ),
        SizedBox(height: short ? 14 : 18),
        _FilterBar(
          typeLabel: _typeKey ?? 'All types',
          typeOptions: typeOptions,
          selectedFilter: _filter,
          onTypeSelected: (value) {
            setState(() {
              _typeKey = value;
              _syncSelection(snapshot);
            });
          },
          onFilterChanged: (value) {
            setState(() {
              _filter = value;
              _syncSelection(snapshot);
            });
          },
        ),
        SizedBox(height: short ? 16 : 20),
        _SectionHeader(
          title: 'Select a Topic',
          actionLabel: 'View Syllabus >',
          onAction: () => Navigator.of(context).pushNamed(AppRoutes.catalog),
        ),
        const SizedBox(height: 12),
        if (snapshot.isEmpty)
          const _InlineEmpty(message: 'No tests assigned yet.')
        else if (visible.isEmpty)
          const _InlineEmpty(message: 'No tests match this filter.')
        else
          _TopicGrid(
            items: visible,
            selectedId: selected?.id,
            onSelect: (item) => setState(() => _selectedId = item.id),
            onOpen: _openTest,
          ),
        SizedBox(height: short ? 16 : 22),
        _SectionHeader(
          title: 'Questions',
          actionLabel: 'Change Mode',
          onAction: _scrollToModes,
          actionIcon: Icons.tune_rounded,
        ),
        const SizedBox(height: 12),
        if (selected == null)
          const _InlineEmpty(
            message: 'Choose a topic above to open practice.',
          )
        else
          _QuestionsPreviewCard(
            item: selected,
            index: selectedIndex < 0 ? 0 : selectedIndex,
            total: visible.length,
            onClear: () => setState(() => _selectedId = null),
            onPrevious: () => _selectAdjacent(visible, -1),
            onNext: () => _selectAdjacent(visible, 1),
            onSkip: () => _selectAdjacent(visible, 1),
            onStart: () => _openTest(selected),
            onOpen: () => _openTest(selected),
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
    required this.onHistory,
  });

  final int unreadCount;
  final String initials;
  final VoidCallback onSearch;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final badge = unreadCount > 99 ? '99+' : '$unreadCount';
    final narrow = MediaQuery.sizeOf(context).width < 360;

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
                  color: _TestsHubScreenState._muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!narrow)
          IconButton(
            tooltip: 'My attempts',
            onPressed: onHistory,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.history_rounded,
              color: _TestsHubScreenState._ink,
            ),
          ),
        IconButton(
          tooltip: 'Quick search',
          onPressed: onSearch,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(
            Icons.search_rounded,
            color: _TestsHubScreenState._ink,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Alerts',
              onPressed: onAlerts,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _TestsHubScreenState._ink,
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
        if (narrow)
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'history') onHistory();
              if (value == 'profile') onProfile();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'history', child: Text('My attempts')),
              PopupMenuItem(value: 'profile', child: Text('Profile')),
            ],
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _TestsHubScreenState._ink,
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
          )
        else ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onProfile,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _TestsHubScreenState._ink,
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
      ],
    );
  }
}

class _PracticeHero extends StatelessWidget {
  const _PracticeHero({required this.narrow, required this.short});

  final bool narrow;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: narrow ? 28 : 32,
            fontWeight: FontWeight.w800,
            color: _TestsHubScreenState._ink,
            height: 1.1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Question practice makes you exam ready. Choose a mode and start practicing.',
          softWrap: true,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: short ? 13 : 14,
            height: 1.4,
            color: _TestsHubScreenState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final art = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: narrow ? 120 : 148,
        maxHeight: short ? 118 : 140,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _SoftBlobPainter()),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 4),
            child: Image.asset(
              'assets/images/practice/hero_practice_student.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, error, stackTrace) => const Icon(
                Icons.school_rounded,
                size: 64,
                color: _TestsHubScreenState._blue,
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 2,
            child: Text(
              'Practice Analyze\nImprove Succeed',
              style: TextStyle(
                fontFamily: AppTheme.scriptFontFamily,
                fontSize: narrow ? 11 : 12,
                height: 1.15,
                color: _TestsHubScreenState._blue.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: art),
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
          child: Align(alignment: Alignment.topRight, child: art),
        ),
      ],
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.selected,
    required this.narrow,
    required this.onChanged,
  });

  final _PracticeMode selected;
  final bool narrow;
  final ValueChanged<_PracticeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cards = <(_PracticeMode, IconData, String, String)>[
      (
        _PracticeMode.byTopic,
        Icons.description_outlined,
        'Practice by Topic',
        'Target specific topics',
      ),
      (
        _PracticeMode.mock,
        Icons.timer_outlined,
        'Mock Test',
        'Full length test experience',
      ),
      (
        _PracticeMode.mixed,
        Icons.shuffle_rounded,
        'Mixed Practice',
        'Random questions from all topics',
      ),
      (
        _PracticeMode.previousYear,
        Icons.history_edu_outlined,
        'Previous Year',
        'Practice past year questions',
      ),
    ];

    // No horizontal scroll — cards reflow to fit the screen width.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 700
            ? 4
            : constraints.maxWidth >= 520
                ? 4
                : 2;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: tileWidth,
                child: _ModeCard(
                  icon: card.$2,
                  title: card.$3,
                  subtitle: card.$4,
                  selected: card.$1 == selected,
                  compact: narrow || columns > 2,
                  onTap: () => onChanged(card.$1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _TestsHubScreenState._blueSoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 104 : 112),
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            compact ? 10 : 12,
            compact ? 10 : 12,
            compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? _TestsHubScreenState._blue
                  : const Color(0xFFE6EAF2),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? _TestsHubScreenState._blue
                    : _TestsHubScreenState._ink,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? _TestsHubScreenState._blue
                      : _TestsHubScreenState._ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: compact ? 10.5 : 11,
                  color: _TestsHubScreenState._muted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeLabel,
    required this.typeOptions,
    required this.selectedFilter,
    required this.onTypeSelected,
    required this.onFilterChanged,
  });

  final String typeLabel;
  final List<String> typeOptions;
  final TestsFilter selectedFilter;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<TestsFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openTypeSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6EAF2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _TestsHubScreenState._ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _TestsHubScreenState._muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in TestsFilter.values)
              _FilterChipButton(
                label: _filterLabel(filter),
                selected: selectedFilter == filter,
                tone: _toneFor(filter),
                onTap: () => onFilterChanged(filter),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _openTypeSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<Object>(
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
                  'Filter by type',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _TestsHubScreenState._ink,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All types'),
                  trailing: typeLabel == 'All types'
                      ? const Icon(
                          Icons.check_rounded,
                          color: _TestsHubScreenState._blue,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, '__all__'),
                ),
                for (final option in typeOptions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option),
                    trailing: typeLabel == option
                        ? const Icon(
                            Icons.check_rounded,
                            color: _TestsHubScreenState._blue,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, option),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    if (selected == '__all__') {
      onTypeSelected(null);
      return;
    }
    onTypeSelected(selected.toString());
  }

  static String _filterLabel(TestsFilter filter) {
    switch (filter) {
      case TestsFilter.all:
        return 'All';
      case TestsFilter.dueSoon:
        return 'Due soon';
      case TestsFilter.practice:
        return 'Practice';
    }
  }

  static _ChipTone _toneFor(TestsFilter filter) {
    switch (filter) {
      case TestsFilter.all:
        return _ChipTone.blue;
      case TestsFilter.dueSoon:
        return _ChipTone.orange;
      case TestsFilter.practice:
        return _ChipTone.teal;
    }
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _ChipTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color border;
    if (selected) {
      bg = _TestsHubScreenState._blue;
      fg = Colors.white;
      border = _TestsHubScreenState._blue;
    } else {
      switch (tone) {
        case _ChipTone.blue:
          bg = _TestsHubScreenState._blueSoft;
          fg = _TestsHubScreenState._blue;
          border = _TestsHubScreenState._blueSoft;
        case _ChipTone.teal:
          bg = _TestsHubScreenState._tealSoft;
          fg = _TestsHubScreenState._green;
          border = _TestsHubScreenState._tealSoft;
        case _ChipTone.orange:
          bg = _TestsHubScreenState._orangeSoft;
          fg = const Color(0xFFC47A1A);
          border = _TestsHubScreenState._orangeSoft;
        case _ChipTone.red:
          bg = _TestsHubScreenState._redSoft;
          fg = const Color(0xFFC0392B);
          border = _TestsHubScreenState._redSoft;
      }
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
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
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData? actionIcon;

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
              color: _TestsHubScreenState._ink,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: _TestsHubScreenState._blue,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (actionIcon != null) ...[
                Icon(actionIcon, size: 16),
                const SizedBox(width: 4),
              ],
              Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.onOpen,
  });

  final List<TestListItem> items;
  final String? selectedId;
  final ValueChanged<TestListItem> onSelect;
  final ValueChanged<TestListItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 3 : 2;
        const gap = 10.0;
        final tileWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: tileWidth,
                child: _TopicCard(
                  item: items[i],
                  accentIndex: i,
                  selected: items[i].id == selectedId,
                  onTap: () => onSelect(items[i]),
                  onOpen: () => onOpen(items[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.item,
    required this.accentIndex,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final TestListItem item;
  final int accentIndex;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(accentIndex, item.type);
    final countLabel = item.questionsCount != null && item.questionsCount! > 0
        ? '${item.questionsCount} Questions'
        : item.typeLabel;

    return Material(
      color: selected ? palette.$1 : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _TestsHubScreenState._blue : palette.$2,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.$1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(palette.$3, color: palette.$4, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _TestsHubScreenState._ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      countLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: _TestsHubScreenState._muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Material(
                    color: _TestsHubScreenState._blue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onOpen,
                      child: const SizedBox(
                        width: 26,
                        height: 26,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (item.due?.label != null && item.due!.label!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DueChip(
                  label: item.due!.label!,
                  urgency: item.due!.urgency,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static (Color, Color, IconData, Color) _paletteFor(int index, TestKind type) {
    final icon = _iconFor(type);
    switch (index % 4) {
      case 0:
        return (
          _TestsHubScreenState._blueSoft,
          const Color(0xFFD6E6FF),
          icon,
          _TestsHubScreenState._blue,
        );
      case 1:
        return (
          _TestsHubScreenState._orangeSoft,
          const Color(0xFFFFE0BF),
          icon,
          const Color(0xFFC47A1A),
        );
      case 2:
        return (
          _TestsHubScreenState._tealSoft,
          const Color(0xFFC8EEDF),
          icon,
          _TestsHubScreenState._green,
        );
      default:
        return (
          const Color(0xFFF3E9FF),
          const Color(0xFFE2D0FF),
          icon,
          const Color(0xFF7B5CFF),
        );
    }
  }

  static IconData _iconFor(TestKind type) {
    switch (type) {
      case TestKind.exam:
        return Icons.assignment_outlined;
      case TestKind.quiz:
        return Icons.quiz_outlined;
      case TestKind.assignment:
        return Icons.edit_note_outlined;
      case TestKind.practice:
        return Icons.fitness_center_outlined;
      case TestKind.other:
        return Icons.fact_check_outlined;
    }
  }
}

class _QuestionsPreviewCard extends StatelessWidget {
  const _QuestionsPreviewCard({
    required this.item,
    required this.index,
    required this.total,
    required this.onClear,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
    required this.onStart,
    required this.onOpen,
  });

  final TestListItem item;
  final int index;
  final int total;
  final VoidCallback onClear;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final dueLabel = item.due?.label;
    final progress = total <= 0 ? 0.0 : (index + 1) / total;
    final marksLabel = item.totalMarks != null
        ? '+${item.totalMarks} marks'
        : item.typeLabel;
    final durationLabel =
        item.durationMinutes != null && item.durationMinutes! > 0
            ? _formatDuration(item.durationMinutes!)
            : 'Open when ready';

    final facts = <(String, String)>[
      ('Type', item.typeLabel),
      if (item.questionsCount != null && item.questionsCount! > 0)
        ('Questions', '${item.questionsCount}'),
      if (item.totalMarks != null) ('Total marks', '${item.totalMarks}'),
      if (item.durationMinutes != null && item.durationMinutes! > 0)
        ('Duration', '${item.durationMinutes} min'),
      if (dueLabel != null && dueLabel.isNotEmpty) ('Deadline', dueLabel),
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 340;
                final meta = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Q${index + 1} of $total',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _TestsHubScreenState._muted,
                      ),
                    ),
                    _MetaPill(
                      label: item.typeLabel,
                      background: _TestsHubScreenState._orangeSoft,
                      foreground: const Color(0xFFC47A1A),
                    ),
                    _MetaPill(
                      label: marksLabel,
                      background: _TestsHubScreenState._greenSoft,
                      foreground: _TestsHubScreenState._green,
                    ),
                  ],
                );
                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Open assessment',
                      onPressed: onOpen,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.bookmark_border_rounded,
                        color: _TestsHubScreenState._muted,
                      ),
                    ),
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: _TestsHubScreenState._blue,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: const Text(
                        'Skip >',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      meta,
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: meta),
                    actions,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item.title,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _TestsHubScreenState._ink,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (item.description ?? '').trim().isNotEmpty
                  ? item.description!.trim()
                  : 'Open this assessment to answer questions and submit your attempt.',
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: _TestsHubScreenState._muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < facts.length; i++) ...[
              _FactOption(
                letter: String.fromCharCode(65 + i),
                label: '${facts[i].$1}: ${facts[i].$2}',
                selected: i == 0,
                onTap: onOpen,
              ),
              if (i < facts.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 340;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        foregroundColor: _TestsHubScreenState._muted,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Clear Answer',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (compact) ...[
                          IconButton.outlined(
                            onPressed: index <= 0 ? null : onPrevious,
                            tooltip: 'Previous',
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: onNext,
                            tooltip: 'Next',
                            style: IconButton.styleFrom(
                              backgroundColor: _TestsHubScreenState._blue,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            onPressed: index <= 0 ? null : onPrevious,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _TestsHubScreenState._ink,
                              side: const BorderSide(color: Color(0xFFD7DEEA)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: onNext,
                            style: FilledButton.styleFrom(
                              backgroundColor: _TestsHubScreenState._blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: const Text('Next'),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE6EAF2)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackFooter = constraints.maxWidth < 360;
                final meta = Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: _TestsHubScreenState._muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Time Left $durationLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _TestsHubScreenState._muted,
                        ),
                      ),
                    ),
                  ],
                );
                final progressBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE8EEF6),
                        color: _TestsHubScreenState._green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${index + 1} of $total',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _TestsHubScreenState._muted,
                      ),
                    ),
                  ],
                );
                final submit = FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: _TestsHubScreenState._blueSoft,
                    foregroundColor: _TestsHubScreenState._blue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text(
                    'Submit Test',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                );

                if (stackFooter) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      meta,
                      const SizedBox(height: 10),
                      progressBlock,
                      const SizedBox(height: 10),
                      submit,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: meta),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: progressBlock),
                    const SizedBox(width: 10),
                    submit,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}:00';
  }
}

class _FactOption extends StatelessWidget {
  const _FactOption({
    required this.letter,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _TestsHubScreenState._blueSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? _TestsHubScreenState._blue
                  : const Color(0xFFE6EAF2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? _TestsHubScreenState._blue
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? _TestsHubScreenState._blue
                        : const Color(0xFFC5CDD9),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _TestsHubScreenState._ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _TestsHubScreenState._ink,
                    height: 1.3,
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.label, required this.urgency});

  final String label;
  final DueUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final urgent = urgency == DueUrgency.overdue ||
        urgency == DueUrgency.endsSoon ||
        urgency == DueUrgency.dueToday;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent
            ? _TestsHubScreenState._redSoft
            : _TestsHubScreenState._greenSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: urgent
              ? const Color(0xFFC0392B)
              : _TestsHubScreenState._green,
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        message,
        softWrap: true,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: _TestsHubScreenState._muted,
          height: 1.45,
        ),
      ),
    );
  }
}

class _SoftBlobPainter extends CustomPainter {
  const _SoftBlobPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFDCEBFF),
          Color(0xFFEAF3FF),
          Color(0xFFF7FAFF),
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.12)
      ..cubicTo(
        size.width * 0.02,
        size.height * 0.28,
        size.width * 0.05,
        size.height * 0.72,
        size.width * 0.28,
        size.height * 0.88,
      )
      ..cubicTo(
        size.width * 0.52,
        size.height * 1.02,
        size.width * 0.92,
        size.height * 0.82,
        size.width * 0.96,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 1.0,
        size.height * 0.18,
        size.width * 0.72,
        size.height * 0.0,
        size.width * 0.18,
        size.height * 0.12,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
