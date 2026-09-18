import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/notification_preferences/data/notification_preferences_repository.dart';
import 'package:student_mobile/features/notification_preferences/domain/notification_preferences_models.dart';

/// S-75 Notification preferences — channel toggles.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({
    super.key,
    this.preferencesRepository,
  });

  final NotificationPreferencesGateway? preferencesRepository;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late final NotificationPreferencesGateway _repo =
      widget.preferencesRepository ?? NotificationPreferencesRepository();

  bool _loading = true;
  NotificationChannelId? _savingChannel;
  String? _error;
  NotificationPreferencesSnapshot _snapshot =
      const NotificationPreferencesSnapshot();

  static const _order = NotificationChannelId.values;

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
      final snapshot = await _repo.load();
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
            : 'Unable to load notification preferences.';
      });
    }
  }

  Future<void> _toggle(NotificationChannelId channel, bool enabled) async {
    if (_savingChannel != null) return;
    final previous = _snapshot;
    setState(() {
      _savingChannel = channel;
      _snapshot = _snapshot.withToggle(channel, enabled);
    });
    try {
      final updated = await _repo.update(channel: channel, enabled: enabled);
      if (!mounted) return;
      setState(() {
        _snapshot = updated;
        _savingChannel = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = previous;
        _savingChannel = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : "Couldn't update preference.",
          ),
        ),
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
          title: const Text('Notification preferences'),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && _snapshot.channels.isEmpty
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
                              onPressed: _load,
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        const Text(
                          'Choose how Pragyu may contact you about tests, scores, and institute updates.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.brandSoft),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < _order.length; i++) ...[
                                  if (i > 0) const Divider(height: 1),
                                  SwitchListTile.adaptive(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      _order[i].title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _order[i].subtitle,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    value: _snapshot.isEnabled(_order[i]),
                                    activeThumbColor: AppColors.brand,
                                    onChanged: _savingChannel == _order[i]
                                        ? null
                                        : (value) => _toggle(_order[i], value),
                                  ),
                                ],
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
}
