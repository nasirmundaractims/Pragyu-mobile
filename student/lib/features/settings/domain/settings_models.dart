/// S-71 Settings (full) — password, sessions, language, devices.

class AuthSessionItem {
  const AuthSessionItem({
    required this.id,
    this.ipAddress,
    this.userAgent,
    this.deviceId,
    this.lastActivityAt,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceId;
  final DateTime? lastActivityAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  String get title {
    final agent = userAgent?.trim();
    if (agent != null && agent.isNotEmpty) {
      return _shortUserAgent(agent);
    }
    final device = deviceId?.trim();
    if (device != null && device.isNotEmpty) return device;
    return 'Session';
  }

  String get subtitle {
    final ip = (ipAddress?.trim().isNotEmpty == true) ? ipAddress!.trim() : '—';
    final when = lastActivityAt ?? createdAt;
    final active = when == null ? '—' : _formatWhen(when);
    return '$ip · last active $active';
  }

  factory AuthSessionItem.fromJson(Map<String, dynamic> json) {
    return AuthSessionItem(
      id: json['id']?.toString() ?? '',
      ipAddress: _nullable(json['ip_address']?.toString()),
      userAgent: _nullable(json['user_agent']?.toString()),
      deviceId: _nullable(json['device_id']?.toString()),
      lastActivityAt: _parseDate(json['last_activity_at']?.toString()),
      expiresAt: _parseDate(json['expires_at']?.toString()),
      createdAt: _parseDate(json['created_at']?.toString()),
    );
  }
}

class TrustedDeviceItem {
  const TrustedDeviceItem({
    required this.id,
    required this.name,
    this.lastSeenAt,
    this.trustedUntil,
  });

  final String id;
  final String name;
  final DateTime? lastSeenAt;
  final DateTime? trustedUntil;

  String get subtitle {
    if (lastSeenAt == null) return 'Trusted device';
    return 'Last seen ${_formatWhen(lastSeenAt!)}';
  }

  factory TrustedDeviceItem.fromJson(Map<String, dynamic> json) {
    return TrustedDeviceItem(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? 'Device').toString(),
      lastSeenAt: _parseDate(json['last_seen_at']?.toString()),
      trustedUntil: _parseDate(json['trusted_until']?.toString()),
    );
  }
}

class LocaleTimezoneSettings {
  const LocaleTimezoneSettings({
    this.locale = 'en',
    this.timezone = 'Asia/Kolkata',
  });

  final String locale;
  final String timezone;

  LocaleTimezoneSettings copyWith({
    String? locale,
    String? timezone,
  }) {
    return LocaleTimezoneSettings(
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
    );
  }
}

class SettingsSnapshot {
  const SettingsSnapshot({
    this.localeTimezone = const LocaleTimezoneSettings(),
    this.sessions = const [],
    this.devices = const [],
    this.sessionsUnavailable = false,
    this.devicesUnavailable = false,
  });

  final LocaleTimezoneSettings localeTimezone;
  final List<AuthSessionItem> sessions;
  final List<TrustedDeviceItem> devices;
  final bool sessionsUnavailable;
  final bool devicesUnavailable;
}

class PasswordChangeRequest {
  const PasswordChangeRequest({
    required this.currentPassword,
    required this.password,
    required this.passwordConfirmation,
  });

  final String currentPassword;
  final String password;
  final String passwordConfirmation;
}

/// Client-side password rules aligned with web change-password schema.
String? validateNewPassword(String password, String confirmation) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters';
  }
  final pattern = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$');
  if (!pattern.hasMatch(password)) {
    return 'Password must include uppercase, lowercase, a number, and a special character';
  }
  if (password != confirmation) {
    return 'Passwords do not match';
  }
  return null;
}

const kLocaleOptions = <(String, String)>[
  ('en', 'English'),
  ('hi', 'Hindi'),
  ('gu', 'Gujarati'),
];

const kTimezoneOptions = <String>[
  'Asia/Kolkata',
  'Asia/Dubai',
  'UTC',
  'America/New_York',
  'Europe/London',
];

String _shortUserAgent(String agent) {
  if (agent.length <= 48) return agent;
  return '${agent.substring(0, 45)}…';
}

String _formatWhen(DateTime value) {
  const months = [
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
  final local = value.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${months[local.month - 1]} ${local.day}, $hh:$mm';
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String? _nullable(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
