import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/settings/data/settings_repository.dart';
import 'package:student_mobile/features/settings/domain/settings_models.dart';
import 'package:student_mobile/features/settings/presentation/screens/settings_screen.dart';

class _FakeSettings implements SettingsGateway {
  _FakeSettings(this.snapshot);

  SettingsSnapshot snapshot;
  PasswordChangeRequest? lastPassword;
  LocaleTimezoneSettings? lastLocale;
  final revokedSessions = <String>[];
  final revokedDevices = <String>[];
  var revokeOthersCount = 0;

  @override
  Future<SettingsSnapshot> loadSettings() async => snapshot;

  @override
  Future<void> changePassword(PasswordChangeRequest request) async {
    lastPassword = request;
  }

  @override
  Future<void> saveLocaleTimezone(LocaleTimezoneSettings settings) async {
    lastLocale = settings;
    snapshot = SettingsSnapshot(
      localeTimezone: settings,
      sessions: snapshot.sessions,
      devices: snapshot.devices,
    );
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    revokedSessions.add(sessionId);
    snapshot = SettingsSnapshot(
      localeTimezone: snapshot.localeTimezone,
      sessions: snapshot.sessions.where((s) => s.id != sessionId).toList(),
      devices: snapshot.devices,
    );
  }

  @override
  Future<void> revokeOtherSessions() async {
    revokeOthersCount += 1;
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    revokedDevices.add(deviceId);
    snapshot = SettingsSnapshot(
      localeTimezone: snapshot.localeTimezone,
      sessions: snapshot.sessions,
      devices: snapshot.devices.where((d) => d.id != deviceId).toList(),
    );
  }
}

void main() {
  testWidgets('S-71 shows password, locale, sessions, and devices',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeSettings(
      SettingsSnapshot(
        localeTimezone: const LocaleTimezoneSettings(
          locale: 'en',
          timezone: 'Asia/Kolkata',
        ),
        sessions: [
          AuthSessionItem(
            id: 's1',
            ipAddress: '10.0.0.1',
            userAgent: 'Chrome Mobile',
            lastActivityAt: DateTime(2026, 9, 16, 10),
          ),
        ],
        devices: const [
          TrustedDeviceItem(id: 'd1', name: 'Pixel 8'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsScreen(settingsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Language & timezone'), findsOneWidget);
    expect(find.text('Active sessions'), findsOneWidget);
    expect(find.text('Trusted devices'), findsOneWidget);
    expect(find.text('Chrome Mobile'), findsOneWidget);
    expect(find.text('Pixel 8'), findsOneWidget);

    await tester.tap(find.text('Revoke').first);
    await tester.pumpAndSettle();
    expect(fake.revokedSessions, ['s1']);
  });

  testWidgets('S-71 empty sessions and devices states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsScreen(
          settingsRepository: _FakeSettings(const SettingsSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No sessions returned.'), findsOneWidget);
    expect(find.text('No trusted devices yet.'), findsOneWidget);
    expect(find.text('Update password'), findsOneWidget);
  });
}
