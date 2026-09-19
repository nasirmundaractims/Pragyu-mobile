import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/home/domain/greeting.dart';
import 'package:student_mobile/features/learn/data/learn_repository.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';

/// S-21 Course detail — modules, progress, Continue CTA (Pragyu redesign).
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.args,
    this.learnRepository,
    this.sessionService,
  });

  final CourseDetailArgs args;
  final LearnGateway? learnRepository;
  final SessionService? sessionService;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

enum _CourseTab { overview, content, instructors, reviews, faqs }

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _blueSoft = Color(0xFFE8F1FF);
  static const _green = Color(0xFF22A06B);
  static const _pageBg = Color(0xFFF4F7FB);
  static const _scriptAsset = 'assets/images/learn/knowledge_builds_script.png';

  late final LearnGateway _learn =
      widget.learnRepository ?? LearnRepository();
  late final SessionService _session =
      widget.sessionService ?? SessionService();

  final _contentKey = GlobalKey();
  final Set<String> _expandedModules = <String>{};

  bool _loading = true;
  bool _expandAll = true;
  String? _error;
  CourseDetailSnapshot? _snapshot;
  String _firstName = 'Student';
  _CourseTab _tab = _CourseTab.overview;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSessionName();
  }

  Future<void> _loadSessionName() async {
    try {
      final session = await _session.read();
      final user = session?.cachedUser;
      if (!mounted || user == null) return;
      setState(() {
        _firstName = greetingFirstName(
          firstName: user.firstName,
          fallbackDisplayName: user.displayName,
        );
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _learn.loadCourseDetail(widget.args);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _expandedModules
          ..clear()
          ..addAll(snapshot.modules.map((m) => m.id));
        _expandAll = snapshot.modules.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load this course. Pull to retry.';
        _loading = false;
      });
    }
  }

  void _openLesson(CourseLesson lesson) {
    Navigator.of(context).pushNamed(
      AppRoutes.lessonPlayer,
      arguments: LessonDetailArgs(
        lessonId: lesson.id,
        courseId: _snapshot?.courseId ?? widget.args.courseId,
        title: lesson.title,
      ),
    );
  }

  void _openLectures() {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.lecturesList,
      arguments: LecturesListArgs(
        courseId: snapshot.courseId,
        courseTitle: snapshot.displayTitle,
      ),
    );
  }

  void _openMaterials() {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.studyMaterials,
      arguments: StudyMaterialsListArgs(
        courseId: snapshot.courseId,
        courseTitle: snapshot.displayTitle,
      ),
    );
  }

  void _scrollToContent() {
    setState(() => _tab = _CourseTab.content);
    final target = _contentKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _toggleExpandAll() {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.modules.isEmpty) return;
    setState(() {
      if (_expandAll) {
        _expandedModules.clear();
        _expandAll = false;
      } else {
        _expandedModules
          ..clear()
          ..addAll(snapshot.modules.map((m) => m.id));
        _expandAll = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: _buildScaffoldBody(),
        bottomNavigationBar: _snapshot == null ? null : _BottomCtaBar(
          continueLesson: _snapshot!.continueLesson,
          courseCompleted: _snapshot!.progress.courseCompleted,
          onContinue: () {
            final lesson = _snapshot!.continueLesson;
            if (lesson != null) _openLesson(lesson);
          },
        ),
      ),
    );
  }

  Widget _buildScaffoldBody() {
    if (_loading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    if (_error != null && _snapshot == null) {
      return SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFC0392B), height: 1.45),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: _blue),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _blue,
      onRefresh: _load,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final snapshot = _snapshot!;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 360;
    final short = size.height < 700;
    final continueLesson = snapshot.continueLesson;
    final progress = snapshot.progress;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _HeroHeader(
            title: snapshot.displayTitle,
            subtitle: snapshot.subtitle,
            narrow: narrow,
            short: short,
            onBack: () => Navigator.of(context).maybePop(),
            scriptAsset: _scriptAsset,
          ),
        ),
        SliverToBoxAdapter(
          child: _TabStrip(
            selected: _tab,
            onSelected: (tab) {
              setState(() => _tab = tab);
              if (tab == _CourseTab.content) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToContent();
                });
              }
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 14 : 18,
              14,
              narrow ? 14 : 18,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFC0392B), height: 1.4),
                ),
                const SizedBox(height: 12),
              ],
              if (_tab == _CourseTab.overview || _tab == _CourseTab.content) ...[
                _ProgressPanel(
                  progress: progress,
                  firstName: _firstName,
                  continueLesson: continueLesson,
                  narrow: narrow,
                  onContinue: continueLesson == null
                      ? null
                      : () => _openLesson(continueLesson),
                ),
                const SizedBox(height: 16),
                _FeatureStrip(
                  moduleCount: snapshot.modules.length,
                  lessonCount: progress.totalLessons > 0
                      ? progress.totalLessons
                      : snapshot.modules.fold<int>(
                          0,
                          (sum, m) => sum + m.lessons.length,
                        ),
                  onModules: _scrollToContent,
                  onLectures: _openLectures,
                  onMaterials: _openMaterials,
                  onPractice: () =>
                      Navigator.of(context).pushNamed(AppRoutes.weakTopics),
                  onAi: () =>
                      Navigator.of(context).pushNamed(AppRoutes.aiMentor),
                  onNotes: () => Navigator.of(context)
                      .pushNamed(AppRoutes.notesBookmarks),
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _contentKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Modules',
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: snapshot.hasModules
                                ? _toggleExpandAll
                                : null,
                            style: TextButton.styleFrom(
                              foregroundColor: _blue,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _expandAll ? 'Collapse All' : 'Expand All',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Icon(
                                  _expandAll
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Course Content',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!snapshot.hasModules)
                        const _EmptyModules()
                      else
                        ...snapshot.modules.asMap().entries.map((entry) {
                          final index = entry.key;
                          final module = entry.value;
                          final expanded =
                              _expandedModules.contains(module.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ModuleTile(
                              index: index + 1,
                              module: module,
                              expanded: expanded,
                              continueLessonId: continueLesson?.id,
                              onToggle: () {
                                setState(() {
                                  if (expanded) {
                                    _expandedModules.remove(module.id);
                                  } else {
                                    _expandedModules.add(module.id);
                                  }
                                  _expandAll = _expandedModules.length ==
                                      snapshot.modules.length;
                                });
                              },
                              onLessonTap: _openLesson,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ] else
                _PlaceholderTab(tab: _tab),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.narrow,
    required this.short,
    required this.onBack,
    required this.scriptAsset,
  });

  final String title;
  final String subtitle;
  final bool narrow;
  final bool short;
  final VoidCallback onBack;
  final String scriptAsset;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1730),
            Color(0xFF152A52),
            Color(0xFF1E3A6E),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeroGlowPainter()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 14 : 18,
              topInset + 8,
              narrow ? 14 : 18,
              short ? 18 : 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                      tooltip: 'Back',
                    ),
                    const Spacer(),
                    _RoundIconButton(
                      icon: Icons.favorite_border_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Saved courses coming soon.'),
                          ),
                        );
                      },
                      tooltip: 'Favorite',
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.ios_share_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sharing coming soon.'),
                          ),
                        );
                      },
                      tooltip: 'Share',
                    ),
                  ],
                ),
                SizedBox(height: short ? 14 : 18),
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
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 14,
                                  color: Color(0xFF5CFFB0),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'ENROLLED',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
                              fontSize: narrow ? 24 : 28,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _KnowledgeScript(asset: scriptAsset, narrow: narrow),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    _HeroStat(
                      icon: Icons.menu_book_rounded,
                      label: 'Course access',
                    ),
                    _HeroStat(
                      icon: Icons.schedule_rounded,
                      label: 'Self paced',
                    ),
                    _HeroStat(
                      icon: Icons.verified_rounded,
                      label: 'Progress tracked',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeScript extends StatelessWidget {
  const _KnowledgeScript({
    required this.asset,
    required this.narrow,
  });

  final String asset;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final maxW = narrow ? 88.0 : 102.0;

    Widget image({double opacity = 1}) {
      return Opacity(
        opacity: opacity,
        child: Image.asset(
          asset,
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
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            );
          },
        ),
      );
    }

    return Semantics(
      label: 'Knowledge Builds Better You',
      child: Transform.rotate(
        angle: -0.12,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: 40),
          child: AspectRatio(
            aspectRatio: 950 / 460,
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                Transform.translate(
                  offset: const Offset(0.5, 0),
                  child: image(opacity: 0.9),
                ),
                image(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
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
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.selected,
    required this.onSelected,
  });

  final _CourseTab selected;
  final ValueChanged<_CourseTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <(_CourseTab, String)>[
      (_CourseTab.overview, 'Overview'),
      (_CourseTab.content, 'Content'),
      (_CourseTab.instructors, 'Instructors'),
      (_CourseTab.reviews, 'Reviews'),
      (_CourseTab.faqs, 'FAQs'),
    ];

    return Material(
      color: Colors.white,
      elevation: 0,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, index) {
            final item = items[index];
            final active = selected == item.$1;
            return InkWell(
              onTap: () => onSelected(item.$1),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active
                          ? _CourseDetailScreenState._blue
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active
                        ? _CourseDetailScreenState._blue
                        : _CourseDetailScreenState._muted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.progress,
    required this.firstName,
    required this.continueLesson,
    required this.narrow,
    required this.onContinue,
  });

  final CourseProgressSummary progress;
  final String firstName;
  final CourseLesson? continueLesson;
  final bool narrow;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final percent = progress.completionPercent.clamp(0, 100);
    final fraction = (percent / 100).clamp(0.0, 1.0);
    final continueLabel = continueLesson == null
        ? null
        : (progress.courseCompleted
            ? 'Review: ${continueLesson!.title}'
            : 'Continue: ${continueLesson!.title}');

    final ring = SizedBox(
      width: narrow ? 84 : 96,
      height: narrow ? 84 : 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 8,
              backgroundColor: const Color(0xFFE4EAF2),
              color: _CourseDetailScreenState._green,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: narrow ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: _CourseDetailScreenState._ink,
                ),
              ),
              const Text(
                'Completed',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _CourseDetailScreenState._muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${progress.completionPercent}% complete',
          softWrap: true,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: _CourseDetailScreenState._ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.completedLessons}/${progress.totalLessons} lessons',
          softWrap: true,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _CourseDetailScreenState._muted,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 7,
            backgroundColor: const Color(0xFFE4EAF2),
            color: _CourseDetailScreenState._green,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _CourseDetailScreenState._blueSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.eco_rounded,
                size: 16,
                color: _CourseDetailScreenState._blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Great progress, $firstName! Keep going consistently.',
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: _CourseDetailScreenState._ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final continueBtn = onContinue == null || continueLabel == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  continueLabel,
                  softWrap: true,
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _CourseDetailScreenState._blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (continueLesson != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Resume: ${continueLesson!.title}',
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: _CourseDetailScreenState._muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your Progress',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _CourseDetailScreenState._ink,
            ),
          ),
          const SizedBox(height: 12),
          if (narrow)
            Column(
              children: [
                ring,
                const SizedBox(height: 14),
                details,
                if (continueBtn != null) ...[
                  const SizedBox(height: 12),
                  continueBtn,
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ring,
                const SizedBox(width: 14),
                Expanded(child: details),
              ],
            ),
          if (!narrow && continueBtn != null) ...[
            const SizedBox(height: 12),
            continueBtn,
          ],
        ],
      ),
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip({
    required this.moduleCount,
    required this.lessonCount,
    required this.onModules,
    required this.onLectures,
    required this.onMaterials,
    required this.onPractice,
    required this.onAi,
    required this.onNotes,
  });

  final int moduleCount;
  final int lessonCount;
  final VoidCallback onModules;
  final VoidCallback onLectures;
  final VoidCallback onMaterials;
  final VoidCallback onPractice;
  final VoidCallback onAi;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.description_outlined, '$moduleCount Modules', onModules),
      (Icons.play_circle_outline_rounded, 'Lectures', onLectures),
      (Icons.picture_as_pdf_outlined, 'Materials', onMaterials),
      (Icons.help_outline_rounded, 'Practice', onPractice),
      (Icons.auto_awesome_rounded, 'AI Mentor', onAi),
      (Icons.download_outlined, 'Notes', onNotes),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: items[i].$3,
                child: Container(
                  width: 86,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4EAF2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: _CourseDetailScreenState._blueSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          items[i].$1,
                          size: 18,
                          color: _CourseDetailScreenState._blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _CourseDetailScreenState._ink,
                          height: 1.2,
                        ),
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

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.index,
    required this.module,
    required this.expanded,
    required this.onToggle,
    required this.onLessonTap,
    this.continueLessonId,
  });

  final int index;
  final CourseModule module;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<CourseLesson> onLessonTap;
  final String? continueLessonId;

  @override
  Widget build(BuildContext context) {
    final allDone = module.lessons.isNotEmpty &&
        module.completedCount == module.lessons.length;
    final inProgress = !allDone && module.completedCount > 0;
    final minutes = module.lessons.fold<int>(
      0,
      (sum, lesson) => sum + (lesson.estimatedMinutes ?? 0),
    );

    final progressValue = module.lessons.isEmpty
        ? 0.0
        : (module.completedCount / module.lessons.length).clamp(0.0, 1.0);

    final statusIcon = allDone
        ? const Icon(Icons.check_circle_rounded,
            color: _CourseDetailScreenState._green, size: 22)
        : inProgress
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: progressValue <= 0 ? 0.2 : progressValue,
                  strokeWidth: 2.5,
                  color: _CourseDetailScreenState._blue,
                ),
              )
            : Icon(
                Icons.radio_button_unchecked_rounded,
                color: Colors.grey.shade400,
                size: 22,
              );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4EAF2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    statusIcon,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$index. ',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: _CourseDetailScreenState._ink,
                                  height: 1.25,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  module.title,
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: _CourseDetailScreenState._ink,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            module.lessons.isEmpty
                                ? 'No lessons'
                                : '${module.completedCount}/${module.lessons.length} lessons'
                                    '${minutes > 0 ? ' · ${minutes}m' : ''}',
                            softWrap: true,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: _CourseDetailScreenState._muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (inProgress)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 2),
                        child: TextButton(
                          onPressed: () {
                            CourseLesson? target;
                            for (final lesson in module.lessons) {
                              if (continueLessonId != null &&
                                  lesson.id == continueLessonId) {
                                target = lesson;
                                break;
                              }
                            }
                            if (target == null) {
                              for (final lesson in module.lessons) {
                                if (!lesson.isCompleted) {
                                  target = lesson;
                                  break;
                                }
                              }
                            }
                            target ??=
                                module.lessons.isNotEmpty ? module.lessons.first : null;
                            if (target != null) onLessonTap(target);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: _CourseDetailScreenState._blue,
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _CourseDetailScreenState._muted,
                    ),
                  ],
                ),
              ),
              if (expanded)
                ...module.lessons.map(
                  (lesson) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                    leading: Icon(
                      lesson.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.play_circle_outline_rounded,
                      color: lesson.isCompleted
                          ? _CourseDetailScreenState._green
                          : _CourseDetailScreenState._blue,
                    ),
                    title: Text(
                      lesson.title,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                        color: _CourseDetailScreenState._ink,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      [
                        lesson.statusLabel,
                        if (lesson.topicPath != null &&
                            lesson.topicPath!.isNotEmpty)
                          lesson.topicPath,
                        if (lesson.estimatedMinutes != null)
                          '${lesson.estimatedMinutes} min',
                      ].join(' · '),
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _CourseDetailScreenState._muted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: _CourseDetailScreenState._muted,
                    ),
                    onTap: () => onLessonTap(lesson),
                  ),
                ),
              if (expanded && module.lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No lessons in this module yet.',
                      style: TextStyle(
                        color: _CourseDetailScreenState._muted,
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

class _EmptyModules extends StatelessWidget {
  const _EmptyModules();

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
      child: const Text(
        'No modules published in this course yet.',
        softWrap: true,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: _CourseDetailScreenState._muted,
          height: 1.45,
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.tab});

  final _CourseTab tab;

  @override
  Widget build(BuildContext context) {
    final label = switch (tab) {
      _CourseTab.instructors => 'Instructor profiles will appear here soon.',
      _CourseTab.reviews => 'Reviews will appear here soon.',
      _CourseTab.faqs => 'FAQs will appear here soon.',
      _ => 'Content coming soon.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Text(
        label,
        softWrap: true,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: _CourseDetailScreenState._muted,
          height: 1.45,
        ),
      ),
    );
  }
}

class _BottomCtaBar extends StatelessWidget {
  const _BottomCtaBar({
    required this.continueLesson,
    required this.courseCompleted,
    required this.onContinue,
  });

  final CourseLesson? continueLesson;
  final bool courseCompleted;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x22001A3D),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: _CourseDetailScreenState._green,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Already Enrolled',
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _CourseDetailScreenState._ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Continue anytime',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: _CourseDetailScreenState._muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: continueLesson == null ? null : onContinue,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(
                courseCompleted ? 'Review' : 'Continue Learning',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _CourseDetailScreenState._blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB7C4D8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x552F7BFF), Color(0x00000000)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.2),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.15),
      size.width * 0.42,
      glow,
    );

    final soft = Paint()..color = const Color(0x22A8C8FF);
    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.75),
      size.width * 0.28,
      soft,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
