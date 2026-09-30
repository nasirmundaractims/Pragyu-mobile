import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/share/pragyu_copy.dart';

void main() {
  test('brandPragyuCopiedBody appends via line once', () {
    expect(
      brandPragyuCopiedBody('Hello'),
      'Hello\n\n— via Pragyu',
    );
    expect(
      brandPragyuCopiedBody('Already branded\n\n— via Pragyu'),
      'Already branded\n\n— via Pragyu',
    );
  });

  test('brandPragyuShareCaption keeps title clear', () {
    expect(
      brandPragyuShareCaption('Federalism 101'),
      'Learn on Pragyu — Federalism 101',
    );
    expect(
      brandPragyuShareCaption('Federalism 101', detail: 'Week 2 lesson'),
      'Learn on Pragyu — Federalism 101\nWeek 2 lesson',
    );
  });
}
