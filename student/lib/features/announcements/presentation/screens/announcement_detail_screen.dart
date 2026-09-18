import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/announcements/data/announcements_repository.dart';
import 'package:student_mobile/features/announcements/domain/announcements_models.dart';

/// S-69 Announcement detail — full body + mark-read.
class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.args,
    this.announcementsRepository,
  });

  final AnnouncementDetailArgs args;
  final AnnouncementsGateway? announcementsRepository;

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  late final AnnouncementsGateway _repo =
      widget.announcementsRepository ?? AnnouncementsRepository();

  bool _loading = false;
  String? _error;
  AnnouncementItem? _item;

  @override
  void initState() {
    super.initState();
    _item = widget.args.item;
    if (_item == null) {
      _resolve();
    } else {
      _markRead(_item!.id);
    }
  }

  Future<void> _resolve() async {
    final id = widget.args.resolvedId;
    if (id == null || id.isEmpty) {
      setState(() {
        _error = 'Announcement not found.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await _repo.findById(id);
      if (!mounted) return;
      if (item == null) {
        setState(() {
          _loading = false;
          _error = 'This announcement is no longer available.';
        });
        return;
      }
      setState(() {
        _item = item;
        _loading = false;
      });
      await _markRead(item.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to open announcement.';
      });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _repo.markRead(id);
    } catch (_) {
      // Detail still usable if mark-read fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Announcement'),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && item == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _resolve,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      children: [
                        if (item!.isPinned) ...[
                          const Row(
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: 16,
                                color: AppColors.brand,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Pinned',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brand,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            item.typeLabel,
                            if (item.publishedAt != null)
                              _formatDate(item.publishedAt!),
                          ].join(' · '),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          item.plainBody.isEmpty
                              ? 'No additional details.'
                              : item.plainBody,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: AppColors.ink,
                          ),
                        ),
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
