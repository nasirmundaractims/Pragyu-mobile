import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/notification_preferences/data/notification_preferences_repository.dart';
import 'package:student_mobile/features/notification_preferences/domain/notification_preferences_models.dart';
import 'package:student_mobile/features/notification_preferences/presentation/screens/notification_preferences_screen.dart';

class _FakePrefs implements NotificationPreferencesGateway {
  _FakePrefs([this.snapshot = const NotificationPreferencesSnapshot()]);

  NotificationPreferencesSnapshot snapshot;
  NotificationChannelId? lastChannel;
  bool? lastEnabled;

  @override
  Future<NotificationPreferencesSnapshot> load() async => snapshot;

  @override
  Future<NotificationPreferencesSnapshot> update({
    required NotificationChannelId channel,
    required bool enabled,
  }) async {
    lastChannel = channel;
    lastEnabled = enabled;
    snapshot = snapshot.withToggle(channel, enabled);
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-75 shows channels and toggles email', (tester) async {
    final fake = _FakePrefs(
      NotificationPreferencesSnapshot.fromRows(const [
        {'channel': 'email', 'is_enabled': true},
        {'channel': 'in_app', 'is_enabled': true},
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: NotificationPreferencesScreen(preferencesRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notification preferences'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('In-app alerts'), findsOneWidget);
    expect(find.text('Push notifications'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(fake.lastChannel, NotificationChannelId.email);
    expect(fake.lastEnabled, isFalse);
  });
}
