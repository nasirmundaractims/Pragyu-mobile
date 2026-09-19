import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/catalog/data/catalog_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';

/// S-29 Catalog / Marketplace — discover marketplace listings.
class CatalogBrowseScreen extends StatefulWidget {
  const CatalogBrowseScreen({
    super.key,
    this.catalogRepository,
    this.sessionService,
    this.alertsRepository,
  });

  final CatalogGateway? catalogRepository;
  final SessionService? sessionService;
  final AlertsGateway? alertsRepository;

  @override
  State<CatalogBrowseScreen> createState() => _CatalogBrowseScreenState();
}

enum _MarketTab { all, courses, testSeries, studyMaterial, liveClasses, educators }

class _CatalogBrowseScreenState extends State<CatalogBrowseScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _pageBg = Color(0xFFF8FAFD);
  static const _heroAsset = 'assets/images/auth/hero_home.png';

  late final CatalogGateway _catalog =
      widget.catalogRepository ?? CatalogRepository();
  late final SessionService _session =
      widget.sessionService ?? SessionService();
  late final AlertsGateway _alerts =
      widget.alertsRepository ?? AlertsRepository();

  final _searchController = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  CatalogSnapshot _snapshot = const CatalogSnapshot();
  AuthUser? _user;
  int _unread = 0;
  _MarketTab _tab = _MarketTab.all;
  String? _categoryKey;

  @override
  void initState() {
    super.initState();
    _load();
    _loadChrome();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadChrome() async {
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

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _catalog.loadCatalog(query: query);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load catalog. Pull to retry.';
        _loading = false;
      });
    }
  }

  String get _initials {
    final display = _user?.displayName.trim();
    if (display == null || display.isEmpty) return 'You';
    final parts = display.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'You' : letters;
  }

  List<CatalogListing> get _filtered {
    return _snapshot.items.where(_matchesFilters).toList(growable: false);
  }

  bool _matchesFilters(CatalogListing item) {
    if (_categoryKey != null && _categoryKey!.isNotEmpty) {
      final hay = '${item.category ?? ''} ${item.title} ${item.subtitle ?? ''}'
          .toLowerCase();
      if (!hay.contains(_categoryKey!.toLowerCase())) return false;
    }
    final type = (item.listingType ?? '').toLowerCase();
    switch (_tab) {
      case _MarketTab.all:
        return true;
      case _MarketTab.courses:
        return item.isCourseListing ||
            type.contains('course') ||
            type.contains('program');
      case _MarketTab.testSeries:
        return item.isTestSeriesListing;
      case _MarketTab.studyMaterial:
        return type.contains('material') || type.contains('note');
      case _MarketTab.liveClasses:
        return type.contains('live');
      case _MarketTab.educators:
        return (item.sellerName?.trim().isNotEmpty ?? false);
    }
  }

  List<CatalogListing> get _courses {
    final items = _filtered;
    final courses = items.where((i) => !i.isTestSeriesListing).toList();
    if (courses.isNotEmpty) return courses;
    return items;
  }

  List<CatalogListing> get _testSeries {
    final items = _filtered.where((i) => i.isTestSeriesListing).toList();
    if (items.isNotEmpty) return items;
    // Fallback: show remaining listings so the section is never empty when
    // the catalog has products but no typed test series.
    if (_tab == _MarketTab.all || _tab == _MarketTab.testSeries) {
      return _filtered.where((i) => i.isFeatured || i.isTestSeriesListing).toList();
    }
    return items;
  }

  void _openListing(CatalogListing item) {
    Navigator.of(context).pushNamed(
      AppRoutes.catalogDetail,
      arguments: item.slug.isNotEmpty ? item.slug : item.id,
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
              _MarketHeader(
                initials: _initials,
                unread: _unread,
                onBack: () => Navigator.of(context).maybePop(),
                onCart: () =>
                    Navigator.of(context).pushNamed(AppRoutes.payments),
                onAlerts: () =>
                    Navigator.of(context).pushNamed(AppRoutes.alerts),
                onProfile: () {
                  StudentShell.of(context)?.goToTab(4);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _blue,
                  onRefresh: () => _load(query: _searchController.text),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final filtered = _filtered;
    final courses = _courses;
    final tests = _testSeries;

    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Marketplace',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Discover the best courses, test series and study materials '
                  'from top educators – all in one place.',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    height: 1.4,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                _SearchField(
                  controller: _searchController,
                  onSubmit: (value) => _load(query: value),
                ),
                const SizedBox(height: 14),
                _TypeTabs(
                  selected: _tab,
                  onSelected: (tab) => setState(() => _tab = tab),
                ),
                const SizedBox(height: 12),
                _CategoryRow(
                  selectedKey: _categoryKey,
                  onSelected: (key) => setState(() {
                    if (key.isEmpty) {
                      _categoryKey = null;
                    } else {
                      _categoryKey = _categoryKey == key ? null : key;
                    }
                  }),
                ),
                const SizedBox(height: 16),
                _PromoBanner(
                  heroAsset: _heroAsset,
                  onExplore: () {
                    setState(() {
                      _tab = _MarketTab.all;
                      _categoryKey = null;
                    });
                    _scroll.animateTo(
                      320,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (_loading && _snapshot.items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: _blue)),
          )
        else if (_error != null && _snapshot.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                softWrap: true,
                style: const TextStyle(color: Color(0xFFC0392B), height: 1.4),
              ),
            ),
          )
        else if (filtered.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Text(
                'No courses found yet. Try another search, or check back soon.',
                softWrap: true,
                style: TextStyle(color: _muted, height: 1.45),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Popular Courses',
              onViewAll: () => setState(() => _tab = _MarketTab.courses),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 292,
              child: _HScrollStrip(
                height: 292,
                children: [
                  for (final item in courses.take(12))
                    _CourseCard(
                      item: item,
                      onTap: () => _openListing(item),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Top Test Series',
              onViewAll: () => setState(() => _tab = _MarketTab.testSeries),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 148,
              child: _HScrollStrip(
                height: 148,
                children: [
                  for (final item in (tests.isNotEmpty ? tests : courses)
                      .take(12))
                    _TestSeriesCard(
                      item: item,
                      onTap: () => _openListing(item),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: _OfferBanner(
                onViewOffers: () {
                  setState(() {
                    _tab = _MarketTab.all;
                    _categoryKey = null;
                  });
                  _load(query: 'offer');
                },
              ),
            ),
          ),
          if (_tab != _MarketTab.all ||
              (_searchController.text.trim().isNotEmpty))
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _ListRow(
                    item: item,
                    onTap: () => _openListing(item),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _MentorDragScrollBehavior extends MaterialScrollBehavior {
  const _MentorDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _HScrollStrip extends StatefulWidget {
  const _HScrollStrip({
    required this.height,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final double height;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  State<_HScrollStrip> createState() => _HScrollStripState();
}

class _HScrollStripState extends State<_HScrollStrip> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is! PointerScrollEvent || !_controller.hasClients) return;
      final position = _controller.position;
      final delta = resolved.scrollDelta.dy != 0
          ? resolved.scrollDelta.dy
          : resolved.scrollDelta.dx;
      final next = (_controller.offset + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (next != _controller.offset) {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'Nothing here yet',
            style: TextStyle(color: _CatalogBrowseScreenState._muted),
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: const _MentorDragScrollBehavior(),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: widget.padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  widget.children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketHeader extends StatelessWidget {
  const _MarketHeader({
    required this.initials,
    required this.unread,
    required this.onBack,
    required this.onCart,
    required this.onAlerts,
    required this.onProfile,
  });

  final String initials;
  final int unread;
  final VoidCallback onBack;
  final VoidCallback onCart;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final badge = unread > 99 ? '99+' : '$unread';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _CatalogBrowseScreenState._ink,
            ),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PragyuLogo(height: 30, semanticsLabel: 'Pragyu'),
                SizedBox(height: 2),
                Text(
                  'Learn • Practice • Grow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: _CatalogBrowseScreenState._muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Billing',
            onPressed: onCart,
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: _CatalogBrowseScreenState._ink,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Alerts',
                onPressed: onAlerts,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _CatalogBrowseScreenState._ink,
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
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
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _CatalogBrowseScreenState._ink,
              child: Text(
                initials.length > 2 ? initials.substring(0, 2) : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmit,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: _CatalogBrowseScreenState._ink,
      ),
      decoration: InputDecoration(
        hintText: 'Search for courses, educators, exams or topics...',
        hintStyle: const TextStyle(
          color: _CatalogBrowseScreenState._muted,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: _CatalogBrowseScreenState._muted,
        ),
        suffixIcon: IconButton(
          tooltip: 'Search',
          onPressed: () => onSubmit(controller.text),
          icon: const Icon(
            Icons.arrow_forward_rounded,
            color: _CatalogBrowseScreenState._blue,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE6EAF2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE6EAF2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _CatalogBrowseScreenState._blue),
        ),
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.selected,
    required this.onSelected,
  });

  final _MarketTab selected;
  final ValueChanged<_MarketTab> onSelected;

  static const _labels = <(_MarketTab, String)>[
    (_MarketTab.all, 'All'),
    (_MarketTab.courses, 'Courses'),
    (_MarketTab.testSeries, 'Test Series'),
    (_MarketTab.studyMaterial, 'Study Material'),
    (_MarketTab.liveClasses, 'Live Classes'),
    (_MarketTab.educators, 'Educators'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final entry = _labels[index];
          final active = entry.$1 == selected;
          return InkWell(
            onTap: () => onSelected(entry.$1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.$2,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active
                        ? _CatalogBrowseScreenState._ink
                        : _CatalogBrowseScreenState._muted,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  height: 3,
                  width: 28,
                  decoration: BoxDecoration(
                    color: active
                        ? _CatalogBrowseScreenState._blue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selectedKey,
    required this.onSelected,
  });

  final String? selectedKey;
  final ValueChanged<String> onSelected;

  static const _categories = <(String, String, IconData, Color, Color)>[
    ('GPSC', 'GPSC', Icons.account_balance_outlined, Color(0xFF2F7BFF), Color(0xFFE8F0FF)),
    ('UPSC', 'UPSC', Icons.apartment_outlined, Color(0xFFF08A3C), Color(0xFFFFF2E8)),
    ('Government', 'Government Exams', Icons.description_outlined, Color(0xFFE85D75), Color(0xFFFFEEF1)),
    ('State', 'State Exams', Icons.map_outlined, Color(0xFF22A06B), Color(0xFFE8F8F0)),
    ('School', 'School Education', Icons.school_outlined, Color(0xFF7B61FF), Color(0xFFF0EBFF)),
    ('Skill', 'Skill Development', Icons.bar_chart_rounded, Color(0xFF2F7BFF), Color(0xFFE8F3FF)),
    ('', 'All Categories', Icons.grid_view_rounded, Color(0xFF7A8499), Color(0xFFF2F4F8)),
  ];

  @override
  Widget build(BuildContext context) {
    return _HScrollStrip(
      height: 92,
      padding: EdgeInsets.zero,
      children: [
        for (final cat in _categories)
          _CategoryTile(
            label: cat.$2,
            icon: cat.$3,
            tint: cat.$4,
            soft: cat.$5,
            selected: cat.$1.isEmpty
                ? (selectedKey == null || selectedKey!.isEmpty)
                : selectedKey == cat.$1,
            onTap: () => onSelected(cat.$1),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.tint,
    required this.soft,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color soft;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 86,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tint : soft,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: tint, size: 26),
            const Spacer(),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _CatalogBrowseScreenState._ink,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.heroAsset,
    required this.onExplore,
  });

  final String heroAsset;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(narrow ? 14 : 18, 16, narrow ? 10 : 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1E5AD7), Color(0xFF4B8DFF), Color(0xFF7EB6FF)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learn from Top Educators',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quality content. Trusted teachers. Your success, our mission.',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: Color(0xFFE8F0FF),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onExplore,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _CatalogBrowseScreenState._blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore Now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Prepare Practice Progress',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.scriptFontFamily,
                    fontSize: narrow ? 16 : 18,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: narrow ? 88 : 110),
                  child: Image.asset(
                    heroAsset,
                    fit: BoxFit.contain,
                    semanticLabel: 'Marketplace educator',
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const _PromoStat(label: '500+ Expert Educators'),
                const SizedBox(height: 4),
                const _PromoStat(label: '10,000+ Students Learning'),
                const SizedBox(height: 4),
                const _PromoStat(label: 'High Quality Study Material'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoStat extends StatelessWidget {
  const _PromoStat({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 9.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
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
    required this.onViewAll,
  });

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              softWrap: true,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _CatalogBrowseScreenState._ink,
              ),
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: _CatalogBrowseScreenState._blue,
            ),
            child: const Text('View All →'),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.item,
    required this.onTap,
  });

  final CatalogListing item;
  final VoidCallback onTap;

  (String, Color) get _badge {
    if (item.isFeatured) return ('Bestseller', const Color(0xFFF08A3C));
    if ((item.averageRating) >= 4.5 && item.ratingCount > 0) {
      return ('Trending', const Color(0xFFE85D75));
    }
    return ('New', const Color(0xFF22A06B));
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final thumb = item.thumbnailUrl?.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumb != null && thumb.isNotEmpty)
                        Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _thumbFallback(),
                        )
                      else
                        _thumbFallback(),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badge.$2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge.$1,
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
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _CatalogBrowseScreenState._ink,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle?.trim().isNotEmpty == true
                            ? item.subtitle!.trim()
                            : (item.shortDescription?.trim().isNotEmpty == true
                                ? item.shortDescription!.trim()
                                : (item.metaLabel.isNotEmpty
                                    ? item.metaLabel
                                    : 'Complete preparation program')),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          color: _CatalogBrowseScreenState._muted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.menu_book_outlined,
                              size: 12, color: _CatalogBrowseScreenState._muted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              item.format?.trim().isNotEmpty == true
                                  ? item.format!
                                  : (item.level ?? 'Self-paced'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _CatalogBrowseScreenState._muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.ratingCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFF5A623)),
                            const SizedBox(width: 3),
                            Text(
                              '${item.averageRating.toStringAsFixed(1)} (${_compact(item.ratingCount)})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _CatalogBrowseScreenState._muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.salePriceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: _CatalogBrowseScreenState._ink,
                              ),
                            ),
                          ),
                          if (item.listPriceLabel != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              item.listPriceLabel!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _CatalogBrowseScreenState._muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Material(
                            color: _CatalogBrowseScreenState._blue,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: onTap,
                              borderRadius: BorderRadius.circular(8),
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _thumbFallback() {
    return Container(
      color: const Color(0xFFE8F0FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.school_rounded,
        color: _CatalogBrowseScreenState._blue,
        size: 40,
      ),
    );
  }
}

class _TestSeriesCard extends StatelessWidget {
  const _TestSeriesCard({
    required this.item,
    required this.onTap,
  });

  final CatalogListing item;
  final VoidCallback onTap;

  (IconData, Color, Color) get _iconStyle {
    final hash = item.id.hashCode.abs() % 3;
    switch (hash) {
      case 1:
        return (
          Icons.track_changes_rounded,
          const Color(0xFFF08A3C),
          const Color(0xFFFFF2E8),
        );
      case 2:
        return (
          Icons.edit_note_rounded,
          const Color(0xFF7B61FF),
          const Color(0xFFF0EBFF),
        );
      default:
        return (
          Icons.assignment_outlined,
          const Color(0xFF2F7BFF),
          const Color(0xFFE8F0FF),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _iconStyle;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: style.$3,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.$1, color: style.$2, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: _CatalogBrowseScreenState._ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.shortDescription?.trim().isNotEmpty == true
                          ? item.shortDescription!.trim()
                          : (item.subtitle ?? 'Full length tests with solutions'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _CatalogBrowseScreenState._muted,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.ratingCount > 0) ...[
                          const Icon(Icons.star_rounded,
                              size: 13, color: Color(0xFFF5A623)),
                          const SizedBox(width: 2),
                          Text(
                            item.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _CatalogBrowseScreenState._muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          item.salePriceLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _CatalogBrowseScreenState._ink,
                            fontSize: 13,
                          ),
                        ),
                        if (item.listPriceLabel != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            item.listPriceLabel!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: _CatalogBrowseScreenState._muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: const Color(0xFFE8F0FF),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: _CatalogBrowseScreenState._blue,
                      size: 18,
                    ),
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

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({required this.onViewOffers});

  final VoidCallback onViewOffers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE4D7FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.percent_rounded,
              color: Color(0xFF7B61FF),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Special Offer — Get up to 50% off on selected courses. Limited period only!',
              softWrap: true,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                height: 1.35,
                color: _CatalogBrowseScreenState._ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onViewOffers,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7B61FF),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('View Offers →'),
          ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.item,
    required this.onTap,
  });

  final CatalogListing item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _CatalogBrowseScreenState._ink,
                      ),
                    ),
                  ),
                  if (item.isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Featured',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _CatalogBrowseScreenState._blue,
                        ),
                      ),
                    ),
                ],
              ),
              if (item.metaLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.metaLabel,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _CatalogBrowseScreenState._muted,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    item.salePriceLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _CatalogBrowseScreenState._blue,
                    ),
                  ),
                  const Spacer(),
                  if (item.ratingCount > 0)
                    Text(
                      '★ ${item.averageRating.toStringAsFixed(1)} (${item.ratingCount})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _CatalogBrowseScreenState._muted,
                        fontWeight: FontWeight.w600,
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

String _compact(int value) {
  if (value >= 1000) {
    final k = value / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
  }
  return '$value';
}
