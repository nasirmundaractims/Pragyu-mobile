import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/exam_series/data/exam_series_repository.dart';
import 'package:student_mobile/features/exam_series/domain/exam_series_models.dart';

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

  bool _loading = true;
  bool _opening = false;
  String? _error;
  ExamSeriesHubSnapshot _snapshot = const ExamSeriesHubSnapshot();

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
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Question Bank'),
          actions: [
            IconButton(
              tooltip: 'Exam Workspace',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.examWorkspace),
              icon: const Icon(Icons.workspace_premium_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: _loading && _snapshot.packs.isEmpty && _error == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && _snapshot.packs.isEmpty
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: _snapshot.isEmpty
                            ? _EmptyHub(
                                onBrowseCatalog: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.catalog),
                                onBrowseTests: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.home),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _HubHeader(
                                    packCount: _snapshot.packs.length,
                                    onFindMore: () => Navigator.of(context)
                                        .pushNamed(AppRoutes.catalog),
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
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.packCount,
    required this.onFindMore,
  });

  final int packCount;
  final VoidCallback onFindMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
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
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$packCount exam series ${packCount == 1 ? 'pack' : 'packs'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Open a pack to take the included tests. Purchased packs open in the seller workspace when needed.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onFindMore,
              child: const Text('Find more packs'),
            ),
          ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
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
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.brand,
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
                        color: AppColors.ink,
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
                          color: AppColors.muted,
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
                Icon(Icons.auto_awesome, size: 14, color: AppColors.brand),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Opens in the seller workspace so you can take every included test.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
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
        color: AppColors.background,
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
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHub extends StatelessWidget {
  const _EmptyHub({
    required this.onBrowseCatalog,
    required this.onBrowseTests,
  });

  final VoidCallback onBrowseCatalog;
  final VoidCallback onBrowseTests;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFE8EEF6), Color(0xFFECFEFF)],
        ),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x14000000)),
            ),
            child: const Icon(Icons.layers_outlined, color: AppColors.brand),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your exam series hub',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Exam Series packs bundle multiple tests for focused practice. Purchase a pack from the catalog, or ask your academy to assign one — then open it here to start.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onBrowseCatalog,
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            child: const Text('Browse exam series'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onBrowseTests,
            child: const Text('Browse individual tests'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
