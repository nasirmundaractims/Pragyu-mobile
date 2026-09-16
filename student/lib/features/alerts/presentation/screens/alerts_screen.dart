import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/alerts/domain/alerts_models.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';

/// S-50 Alerts — notification + academy inbox for the Alerts tab.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    this.alertsRepository,
    this.onUnreadChanged,
  });

  final AlertsGateway? alertsRepository;
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final AlertsGateway _alerts =
      widget.alertsRepository ?? AlertsRepository();

  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  AlertsSnapshot? _snapshot;
  final Set<String> _markingIds = <String>{};

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
      final snapshot = await _alerts.loadAlerts();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      widget.onUnreadChanged?.call(snapshot.unreadCount);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load alerts. Pull to retry.';
      });
    }
  }

  Future<void> _markRead(AlertItem item) async {
    if (item.isRead || _markingIds.contains(item.id)) return;
    setState(() => _markingIds.add(item.id));
    try {
      await _alerts.markRead(item);
      if (!mounted) return;
      final next = (_snapshot ?? const AlertsSnapshot()).markItemRead(item.id);
      setState(() {
        _snapshot = next;
        _markingIds.remove(item.id);
      });
      widget.onUnreadChanged?.call(next.unreadCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingIds.remove(item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't mark alert as read.")),
      );
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    final current = _snapshot;
    if (current == null || current.pageUnreadCount == 0) return;
    setState(() => _markingAll = true);
    try {
      await _alerts.markAllRead();
      // Also clear unread inbox rows locally when present.
      final unreadInbox = current.items
          .where((item) => !item.isRead && item.source == AlertSource.inbox)
          .toList(growable: false);
      for (final item in unreadInbox) {
        try {
          await _alerts.markRead(item);
        } catch (_) {}
      }
      if (!mounted) return;
      final next = current.markAllRead();
      setState(() {
        _snapshot = next;
        _markingAll = false;
      });
      widget.onUnreadChanged?.call(0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't mark all alerts as read.")),
      );
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
          title: const Text('Alerts'),
          actions: [
            IconButton(
              tooltip: 'Quick search',
              onPressed: () => showQuickSearchSheet(context),
              icon: const Icon(Icons.search_rounded, color: AppColors.ink),
            ),
          ],
        ),
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
          SizedBox(height: 120),
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
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
        ],
      );
    }

    final snapshot = _snapshot ?? const AlertsSnapshot();
    if (snapshot.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
        children: const [
          _EmptyState(),
        ],
      );
    }

    final grouped = snapshot.grouped();
    final unread = snapshot.pageUnreadCount;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        _SummaryBar(
          unread: unread,
          markingAll: _markingAll,
          onMarkAll: unread > 0 ? _markAllRead : null,
        ),
        const SizedBox(height: 18),
        for (final group in AlertDayGroup.values) ...[
          if (grouped[group]!.isNotEmpty) ...[
            Text(
              dayGroupLabel(group),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in grouped[group]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AlertTile(
                  item: item,
                  marking: _markingIds.contains(item.id),
                  onMarkRead: () => _markRead(item),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.unread,
    required this.markingAll,
    this.onMarkAll,
  });

  final int unread;
  final bool markingAll;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              unread > 0
                  ? '$unread unread · grouped by day'
                  : 'All caught up · grouped by day',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onMarkAll == null || markingAll ? null : onMarkAll,
            child: markingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  )
                : const Text('Mark all read'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 36,
            color: AppColors.brand,
          ),
          SizedBox(height: 14),
          Text(
            "You're all caught up",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Evaluation results, learning tips, and academy messages will show up here when they arrive.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.item,
    required this.marking,
    required this.onMarkRead,
  });

  final AlertItem item;
  final bool marking;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return Material(
      color: unread ? AppColors.brandSoft.withValues(alpha: 0.55) : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: unread ? onMarkRead : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread ? AppColors.brand.withValues(alpha: 0.2) : AppColors.brandSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Chip(label: item.categoryLabel),
                  if (unread) ...[
                    const SizedBox(width: 8),
                    const _Chip(label: 'Unread', emphasis: true),
                  ],
                  const Spacer(),
                  if (unread)
                    TextButton(
                      onPressed: marking ? null : onMarkRead,
                      child: marking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brand,
                              ),
                            )
                          : const Text('Mark read'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 15,
                ),
              ),
              if (item.body != null && item.body!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.body!,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
              if (item.createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatAlertTime(item.createdAt!),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.emphasis = false,
  });

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasis ? AppColors.brand : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brandSoft),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: emphasis ? Colors.white : AppColors.ink,
        ),
      ),
    );
  }
}

String _formatAlertTime(DateTime value) {
  final local = value.toLocal();
  final months = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, $hour:$minute $period';
}
