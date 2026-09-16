import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/settings/domain/settings_models.dart';

void main() {
  test('validateNewPassword enforces strength and confirmation', () {
    expect(validateNewPassword('short', 'short'), isNotNull);
    expect(validateNewPassword('Password1!', 'Password2!'), isNotNull);
    expect(validateNewPassword('Password1!', 'Password1!'), isNull);
  });

  test('AuthSessionItem and TrustedDeviceItem parse metadata', () {
    final session = AuthSessionItem.fromJson({
      'id': 's1',
      'ip_address': '1.2.3.4',
      'user_agent': 'Mozilla/5.0 Chrome',
      'last_activity_at': '2026-09-16T10:00:00Z',
      'created_at': '2026-09-01T10:00:00Z',
    });
    expect(session.title.contains('Mozilla'), isTrue);
    expect(session.subtitle.contains('1.2.3.4'), isTrue);

    final device = TrustedDeviceItem.fromJson({
      'id': 'd1',
      'name': 'iPhone',
      'last_seen_at': '2026-09-16T09:00:00Z',
    });
    expect(device.name, 'iPhone');
    expect(device.subtitle.contains('Last seen'), isTrue);
  });
}
