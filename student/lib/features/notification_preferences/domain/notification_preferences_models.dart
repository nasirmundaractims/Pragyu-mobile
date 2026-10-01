import 'package:student_mobile/features/notification_preferences/domain/outbound_channel_capability.dart';
import 'package:student_mobile/features/notification_preferences/domain/push_delivery.dart';

/// S-75 Notification channel preferences.
enum NotificationChannelId {
  email,
  inApp,
  sms,
  whatsapp,
  push,
}

extension NotificationChannelIdX on NotificationChannelId {
  String get apiValue => switch (this) {
        NotificationChannelId.email => 'email',
        NotificationChannelId.inApp => 'in_app',
        NotificationChannelId.sms => 'sms',
        NotificationChannelId.whatsapp => 'whatsapp',
        NotificationChannelId.push => 'push',
      };

  String get title => switch (this) {
        NotificationChannelId.email => 'Email',
        NotificationChannelId.inApp => 'In-app alerts',
        NotificationChannelId.sms => 'SMS',
        NotificationChannelId.whatsapp => 'WhatsApp',
        NotificationChannelId.push => 'Push notifications',
      };

  String get subtitle => switch (this) {
        NotificationChannelId.email => 'Tests, scores, and evaluation updates',
        NotificationChannelId.inApp => 'Alerts tab inbox messages',
        NotificationChannelId.sms => OutboundChannelCapability.smsSubtitle,
        NotificationChannelId.whatsapp =>
          OutboundChannelCapability.whatsappSubtitle,
        NotificationChannelId.push => PushDelivery.pushChannelSubtitle,
      };

  static NotificationChannelId? tryParse(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'email':
        return NotificationChannelId.email;
      case 'in_app':
      case 'in-app':
        return NotificationChannelId.inApp;
      case 'sms':
        return NotificationChannelId.sms;
      case 'whatsapp':
        return NotificationChannelId.whatsapp;
      case 'push':
        return NotificationChannelId.push;
      default:
        return null;
    }
  }
}

class ChannelPreference {
  const ChannelPreference({
    required this.channel,
    required this.isEnabled,
    this.id,
  });

  final NotificationChannelId channel;
  final bool isEnabled;
  final String? id;

  ChannelPreference copyWith({bool? isEnabled}) {
    return ChannelPreference(
      channel: channel,
      isEnabled: isEnabled ?? this.isEnabled,
      id: id,
    );
  }

  factory ChannelPreference.fromJson(Map<String, dynamic> json) {
    final channel = NotificationChannelIdX.tryParse(json['channel']?.toString()) ??
        NotificationChannelId.email;
    return ChannelPreference(
      channel: channel,
      isEnabled: json['is_enabled'] != false,
      id: json['id']?.toString(),
    );
  }
}

class NotificationPreferencesSnapshot {
  const NotificationPreferencesSnapshot({
    this.channels = const {},
  });

  final Map<NotificationChannelId, ChannelPreference> channels;

  bool isEnabled(NotificationChannelId channel) {
    return channels[channel]?.isEnabled ?? _defaultEnabled(channel);
  }

  /// Phase 8 — SMS / WhatsApp / push require opt-in; email + in-app stay opt-out.
  static bool _defaultEnabled(NotificationChannelId channel) {
    return channel == NotificationChannelId.email ||
        channel == NotificationChannelId.inApp;
  }

  NotificationPreferencesSnapshot withToggle(
    NotificationChannelId channel,
    bool enabled,
  ) {
    final next = Map<NotificationChannelId, ChannelPreference>.from(channels);
    final existing = next[channel];
    next[channel] = existing?.copyWith(isEnabled: enabled) ??
        ChannelPreference(channel: channel, isEnabled: enabled);
    return NotificationPreferencesSnapshot(channels: next);
  }

  factory NotificationPreferencesSnapshot.fromRows(
      List<Map<String, dynamic>> rows) {
    final map = <NotificationChannelId, ChannelPreference>{};
    for (final row in rows) {
      final pref = ChannelPreference.fromJson(row);
      map[pref.channel] = pref;
    }
    return NotificationPreferencesSnapshot(channels: map);
  }
}
