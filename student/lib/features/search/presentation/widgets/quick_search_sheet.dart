import 'dart:async';

import 'package:flutter/material.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/search/data/search_repository.dart';
import 'package:student_mobile/features/search/domain/search_models.dart';

/// S-12 Quick search sheet — jump to course, test, or material.
Future<void> showQuickSearchSheet(
  BuildContext context, {
  SearchGateway? searchRepository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return QuickSearchSheet(searchRepository: searchRepository);
    },
  );
}

class QuickSearchSheet extends StatefulWidget {
  const QuickSearchSheet({
    super.key,
    this.searchRepository,
  });

  final SearchGateway? searchRepository;

  @override
  State<QuickSearchSheet> createState() => _QuickSearchSheetState();
}

class _QuickSearchSheetState extends State<QuickSearchSheet> {
  late final SearchGateway _search =
      widget.searchRepository ?? SearchRepository();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  QuickSearchCatalog _catalog = const QuickSearchCatalog();
  QuickSearchResults _results = const QuickSearchResults();
  bool _loadingCatalog = true;
  bool _searchingMaterials = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final catalog = await _search.loadCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load searchable items.';
        _loadingCatalog = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final local = _search.filterCatalog(_catalog, value);
    setState(() {
      _results = QuickSearchResults(
        courses: local.courses,
        tests: local.tests,
        materials: _results.materials,
      );
    });

    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final q = value.trim();
      if (q.length < 2) {
        if (!mounted) return;
        setState(() {
          _results = QuickSearchResults(
            courses: local.courses,
            tests: local.tests,
          );
          _searchingMaterials = false;
        });
        return;
      }
      setState(() => _searchingMaterials = true);
      final materials = await _search.searchMaterials(q);
      if (!mounted) return;
      final refreshedLocal = _search.filterCatalog(_catalog, q);
      setState(() {
        _results = QuickSearchResults(
          courses: refreshedLocal.courses,
          tests: refreshedLocal.tests,
          materials: materials,
        );
        _searchingMaterials = false;
      });
    });
  }

  void _select(SearchHit hit) {
    final shell = StudentShell.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();

    if (hit.kind == SearchHitKind.course) {
      shell?.goToTab(1);
      navigator.pushNamed(
        AppRoutes.courseDetail,
        arguments: CourseDetailArgs(
          courseId: hit.id,
          title: hit.title,
        ),
      );
      return;
    }

    if (hit.kind == SearchHitKind.material) {
      shell?.goToTab(1);
      final type = (hit.materialType ?? '').toLowerCase();
      if (type == 'lesson') {
        navigator.pushNamed(
          AppRoutes.lessonPlayer,
          arguments: LessonDetailArgs(
            lessonId: hit.id,
            title: hit.title,
          ),
        );
        return;
      }
      navigator.pushNamed(
        AppRoutes.materialViewer,
        arguments: MaterialViewerArgs(
          resourceId: hit.id,
          title: hit.title,
          resourceType: hit.materialType,
          isDownloadable: type == 'pdf' || type == 'notes',
        ),
      );
      return;
    }

    shell?.goToTab(hit.tabIndex);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${hit.title} — opens ${hit.nextScreenId} when that screen ships.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final query = _controller.text.trim();
    final showHint = query.length < 2;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quick search',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Jump to course, test, or material',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.brandSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.brandSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingCatalog)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: showHint
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Type at least 2 characters to search your courses, tests, and materials.',
                          style: TextStyle(
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                        ),
                      )
                    : _buildResults(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty && !_searchingMaterials) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No matches. Try another title.',
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (_searchingMaterials)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.brand,
              backgroundColor: AppColors.brandSoft,
            ),
          ),
        if (_results.courses.isNotEmpty) ...[
          const _SectionLabel('Courses'),
          ..._results.courses.map(_hitTile),
        ],
        if (_results.tests.isNotEmpty) ...[
          const _SectionLabel('Tests'),
          ..._results.tests.map(_hitTile),
        ],
        if (_results.materials.isNotEmpty) ...[
          const _SectionLabel('Materials'),
          ..._results.materials.map(_hitTile),
        ],
      ],
    );
  }

  Widget _hitTile(SearchHit hit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _select(hit),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brandSoft),
            ),
            child: Row(
              children: [
                Icon(
                  hit.kind == SearchHitKind.test
                      ? Icons.quiz_outlined
                      : hit.kind == SearchHitKind.course
                          ? Icons.menu_book_outlined
                          : Icons.description_outlined,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          hit.kindLabel,
                          if (hit.subtitle != null && hit.subtitle!.isNotEmpty)
                            hit.subtitle,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.north_east_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
