import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Notification preferences',
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(padding: EdgeInsets.zero);
    }

    if (_error != null && _snapshot.channels.isEmpty) {
      return Center(
        child: AppErrorState(
          message: _error!,
          onRetry: _load,
          retryLabel: 'Retry',
        ),
      );
    }

    return RefreshIndicator(
      color: StudentHubColors.blue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          const _IntroCard(),
          const SizedBox(height: 18),
          const Text(
            'Channels',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: StudentHubColors.muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          for (final channel in _order) ...[
            _ChannelTile(
              channel: channel,
              enabled: _snapshot.isEnabled(channel),
              saving: _savingChannel == channel,
              onChanged: _savingChannel != null
                  ? null
                  : (value) => _toggle(channel, value),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          const Text(
            'You can change these anytime. Critical account messages may still be sent when required.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              height: 1.4,
              color: StudentHubColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: StudentHubColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconWell(
            icon: Icons.notifications_active_rounded,
            tint: StudentHubColors.blue,
            soft: StudentHubColors.blueSoft,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How Pragyu reaches you',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: StudentHubColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose how Pragyu may contact you about tests, scores, and institute updates.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    height: 1.4,
                    color: StudentHubColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.enabled,
    required this.saving,
    required this.onChanged,
  });

  final NotificationChannelId channel;
  final bool enabled;
  final bool saving;
  final ValueChanged<bool>? onChanged;

  (IconData, Color, Color) get _style => switch (channel) {
        NotificationChannelId.email => (
            Icons.mail_outline_rounded,
            StudentHubColors.blue,
            StudentHubColors.blueSoft,
          ),
        NotificationChannelId.inApp => (
            Icons.notifications_none_rounded,
            const Color(0xFFE85D75),
            const Color(0xFFFFEEF1),
          ),
        NotificationChannelId.sms => (
            Icons.sms_outlined,
            const Color(0xFF22A06B),
            const Color(0xFFE8F8F0),
          ),
        NotificationChannelId.whatsapp => (
            Icons.chat_rounded,
            const Color(0xFF25D366),
            const Color(0xFFE8F8EF),
          ),
        NotificationChannelId.push => (
            Icons.phone_iphone_rounded,
            const Color(0xFFF08A3C),
            const Color(0xFFFFF2E8),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, tint, soft) = _style;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
      child: InkWell(
        onTap: onChanged == null || saving
            ? null
            : () => onChanged!(!enabled),
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
            border: Border.all(color: StudentHubColors.border),
          ),
          child: Row(
            children: [
              _IconWell(icon: icon, tint: tint, soft: soft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.title,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: StudentHubColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      channel.subtitle,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        height: 1.35,
                        color: StudentHubColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (saving)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: StudentHubColors.blue,
                  ),
                )
              else
                Switch.adaptive(
                  value: enabled,
                  activeThumbColor: StudentHubColors.blue,
                  activeTrackColor: StudentHubColors.blue.withValues(alpha: 0.35),
                  onChanged: onChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.icon,
    required this.tint,
    required this.soft,
  });

  final IconData icon;
  final Color tint;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: tint, size: 20),
    );
  }
}
