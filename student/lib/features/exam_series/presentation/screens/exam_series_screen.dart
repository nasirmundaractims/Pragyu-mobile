import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
import 'package:student_mobile/features/exam_series/data/exam_series_repository.dart';
import 'package:student_mobile/features/exam_series/domain/exam_series_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';

/// S-67 Exam Series hub — entitled test packs (Question Bank).
class ExamSeriesScreen extends StatefulWidget {
  const ExamSeriesScreen({
    super.key,
    this.seriesRepository,
  });

  final ExamSeriesGateway? seriesRepository;

  @override
  State<ExamSeriesScreen> createState() => _ExamSeriesScreenState();
}

class _ExamSeriesScreenState extends State<ExamSeriesScreen> {
  late final ExamSeriesGateway _repo =
      widget.seriesRepository ?? ExamSeriesRepository();
  final MarketplaceAccessService _marketplace =
      MarketplaceAccessService.instance;

  bool _loading = true;
  bool _opening = false;
  String? _error;
  ExamSeriesHubSnapshot _snapshot = const ExamSeriesHubSnapshot();

  @override
  void initState() {
    super.initState();
    _marketplace.addListener(_onMarketplaceChanged);
    _marketplace.ensureLoaded();
    _load();
  }

  @override
  void dispose() {
    _marketplace.removeListener(_onMarketplaceChanged);
    super.dispose();
  }

  void _onMarketplaceChanged() {
    if (mounted) setState(() {});
  }

  void _openCatalog() {
    if (!_marketplace.available) return;
    Navigator.of(context).pushNamed(AppRoutes.catalog);
  }

  void _openWorkspace() {
    Navigator.of(context).pushNamed(AppRoutes.examWorkspace);
  }

  /// Practice tab is the primary home for assigned individual tests (slice 1.4).
  void _openPractice() {
    final shell = StudentShell.of(context);
    if (shell != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      shell.goToTab(2);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.home);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _repo.loadHub();
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
            : 'Unable to load exam series.';
      });
    }
  }

  Future<void> _openPack(ExamSeriesPack pack) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final needsSwitch =
          pack.needsOrgSwitch(_snapshot.activeOrganizationId);
      await _repo.ensureSellerWorkspace(pack);
      if (!mounted) return;
      if (needsSwitch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opened ${pack.organizationName ?? 'your'} workspace so you can take the included tests.',
            ),
          ),
        );
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.examSeriesDetail,
        arguments: ExamSeriesDetailArgs(
          seriesId: pack.id,
          title: pack.title,
          organizationId: pack.sellerOrganizationId,
          organizationName: pack.organizationName,
        ),
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to open this pack.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Exam Series',
        actions: [
          TextButton.icon(
            onPressed: _openWorkspace,
            icon: const Icon(
              Icons.workspace_premium_outlined,
              size: 18,
              color: StudentHubColors.ink,
            ),
            label: const Text(
              'Workspace',
              style: TextStyle(
                color: StudentHubColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        body: _loading && _snapshot.packs.isEmpty && _error == null
            ? const AppLoadingState(padding: EdgeInsets.zero)
            : _error != null && _snapshot.packs.isEmpty
                ? Center(
                    child: AppErrorState(
                      message: _error!,
                      onRetry: _load,
                      retryLabel: 'Retry',
                    ),
                  )
                : RefreshIndicator(
                    color: StudentHubColors.blue,
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: _snapshot.isEmpty
                          ? _EmptyHub(
                              onBrowseCatalog: _marketplace.available
                                  ? _openCatalog
                                  : null,
                              onBrowseTests: _openPractice,
                              onOpenWorkspace: _openWorkspace,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _HubHeader(
                                  packCount: _snapshot.packs.length,
                                  onFindMore: _marketplace.available
                                      ? _openCatalog
                                      : null,
                                  onOpenWorkspace: _openWorkspace,
                                ),
                                const SizedBox(height: 14),
                                for (final pack in _snapshot.packs) ...[
                                  _PackCard(
                                    pack: pack,
                                    activeOrganizationId:
                                        _snapshot.activeOrganizationId,
                                    opening: _opening,
                                    onOpen: () => _openPack(pack),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                    ),
                  ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.packCount,
    this.onFindMore,
    required this.onOpenWorkspace,
  });

  final int packCount;
  final VoidCallback? onFindMore;
  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentHubColors.surface,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: StudentHubColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'READY TO PRACTICE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: StudentHubColors.blue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$packCount exam series ${packCount == 1 ? 'pack' : 'packs'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: StudentHubColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Open a pack to take the included tests. Purchased packs open in the seller workspace when needed.',
            style: TextStyle(fontSize: 13, color: StudentHubColors.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          Material(
            color: const Color(0xFFF0EBFF),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpenWorkspace,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_outlined,
                      size: 20,
                      color: Color(0xFF7B61FF),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exam Workspace',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: StudentHubColors.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pattern-aware readiness for your target exam',
                            style: TextStyle(
                              fontSize: 12,
                              color: StudentHubColors.muted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: StudentHubColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onFindMore != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onFindMore,
                child: const Text('Find more packs'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.activeOrganizationId,
    required this.opening,
    required this.onOpen,
  });

  final ExamSeriesPack pack;
  final String? activeOrganizationId;
  final bool opening;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final needsSwitch = pack.needsOrgSwitch(activeOrganizationId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentHubColors.surface,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: StudentHubColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: StudentHubColors.blueSoft,
                  borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: StudentHubColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: StudentHubColors.ink,
                      ),
                    ),
                    if (pack.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        pack.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: StudentHubColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Tests',
                  value: '${pack.testsCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'From',
                  value: pack.fromLabel,
                ),
              ),
            ],
          ),
          if (needsSwitch) ...[
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: StudentHubColors.blue),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Opens in the seller workspace so you can take every included test.',
                    style: TextStyle(fontSize: 12, color: StudentHubColors.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: opening ? null : onOpen,
              style: FilledButton.styleFrom(backgroundColor: StudentHubColors.blue),
              child: Text(needsSwitch ? 'Open pack' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: StudentHubColors.pageBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: StudentHubColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: StudentHubColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHub extends StatelessWidget {
  const _EmptyHub({
    this.onBrowseCatalog,
    required this.onBrowseTests,
    required this.onOpenWorkspace,
  });

  final VoidCallback? onBrowseCatalog;
  final VoidCallback onBrowseTests;
  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppEmptyState(
          icon: Icons.layers_outlined,
          title: 'Your exam series hub',
          message:
              'Exam Series packs bundle multiple tests for focused practice. Purchase a pack from the catalog, or ask your academy to assign one — then open it here to start.',
          actionLabel:
              onBrowseCatalog != null ? 'Browse exam series' : null,
          onAction: onBrowseCatalog,
        ),
        SecondaryButton(
          label: 'Browse individual tests',
          onPressed: onBrowseTests,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onOpenWorkspace,
          child: const Text('Open Exam Workspace'),
        ),
      ],
    );
  }
}
