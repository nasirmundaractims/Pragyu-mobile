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
        NotificationChannelId.sms => 'Critical reminders by text message',
        NotificationChannelId.whatsapp => 'Updates via WhatsApp when enabled',
        NotificationChannelId.push =>
          'Device push will activate when store push is enabled',
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

  static bool _defaultEnabled(NotificationChannelId channel) {
    return channel != NotificationChannelId.push;
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

  factory NotificationPreferencesSnapshot.fromRows(List<Map<String, dynamic>> rows) {
    final map = <NotificationChannelId, ChannelPreference>{};
    for (final row in rows) {
      final pref = ChannelPreference.fromJson(row);
      map[pref.channel] = pref;
    }
    return NotificationPreferencesSnapshot(channels: map);
  }
}
