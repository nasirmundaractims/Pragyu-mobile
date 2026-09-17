import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';

void main() {
  test('validateRegisterPassword enforces strength rules', () {
    expect(validateRegisterPassword('short'), isNotNull);
    expect(validateRegisterPassword('password1!'), isNotNull);
    expect(validateRegisterPassword('PASSWORD1!'), isNotNull);
    expect(validateRegisterPassword('Password!'), isNotNull);
    expect(validateRegisterPassword('Password1'), isNotNull);
    expect(validateRegisterPassword('Password1!'), isNull);
  });
}
