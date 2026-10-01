import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/student_hub_colors.dart';
import 'package:student_mobile/app/widgets/student_app_header.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/announcements/data/announcements_repository.dart';
import 'package:student_mobile/features/announcements/domain/announcements_models.dart';

/// S-69 Announcements list — pinned + recent institute notices.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    this.announcementsRepository,
  });

  final AnnouncementsGateway? announcementsRepository;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late final AnnouncementsGateway _repo =
      widget.announcementsRepository ?? AnnouncementsRepository();

  bool _loading = true;
  String? _error;
  AnnouncementsSnapshot _snapshot = const AnnouncementsSnapshot();

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
      final snapshot = await _repo.loadAnnouncements();
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
            : 'Unable to load announcements.';
      });
    }
  }

  void _openDetail(AnnouncementItem item) {
    Navigator.of(context).pushNamed(
      AppRoutes.announcementDetail,
      arguments: AnnouncementDetailArgs(
        announcementId: item.id,
        item: item,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Announcements',
        body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: StudentHubColors.blue),
                )
              : _error != null && _snapshot.items.isEmpty
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: StudentHubColors.blue,
                      onRefresh: _load,
                      child: _snapshot.items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
                              children: const [
                                Icon(
                                  Icons.campaign_outlined,
                                  size: 48,
                                  color: StudentHubColors.muted,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "You're all caught up",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: StudentHubColors.ink,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'When your institute posts a notice, it will show up here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: StudentHubColors.muted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                              children: [
                                const Text(
                                  'Pinned and recent notices from your institute.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: StudentHubColors.muted,
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: StudentHubColors.danger,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if (_snapshot.pinned.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const _SectionLabel('Pinned'),
                                  const SizedBox(height: 8),
                                  ..._snapshot.pinned.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _AnnouncementCard(
                                        item: item,
                                        onTap: () => _openDetail(item),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_snapshot.unpinned.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const _SectionLabel('Recent'),
                                  const SizedBox(height: 8),
                                  ..._snapshot.unpinned.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _AnnouncementCard(
                                        item: item,
                                        onTap: () => _openDetail(item),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.item,
    required this.onTap,
  });

  final AnnouncementItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = item.plainBody;
    return Material(
      color: StudentHubColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StudentHubColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (item.isPinned) ...[
                    const Icon(
                      Icons.push_pin,
                      size: 16,
                      color: StudentHubColors.blue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: StudentHubColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: StudentHubColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  item.typeLabel,
                  if (item.publishedAt != null)
                    _formatDate(item.publishedAt!),
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 12,
                  color: StudentHubColors.muted,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: StudentHubColors.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: StudentHubColors.muted,
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
              style: const TextStyle(color: StudentHubColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: StudentHubColors.blue),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
