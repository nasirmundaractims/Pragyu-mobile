import 'package:flutter_test/flutter_test.dart';

import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/catalog/domain/marketplace_access_models.dart';
import 'package:student_mobile/features/payments/presentation/credit_exhaustion.dart';

void main() {
  group('MarketplaceAccess', () {
    test('parses available false', () {
      final access = MarketplaceAccess.fromJson({
        'available': false,
        'reason': 'Institute disabled marketplace',
      });
      expect(access.available, isFalse);
      expect(access.reason, 'Institute disabled marketplace');
    });

    test('defaults to available when missing', () {
      final access = MarketplaceAccess.fromJson({});
      expect(access.available, isTrue);
    });
  });

  group('isCreditExhaustedError', () {
    test('detects CREDIT_INSUFFICIENT code', () {
      final error = ApiException(
        message: 'Not enough credits',
        statusCode: 422,
        code: 'CREDIT_INSUFFICIENT',
      );
      expect(isCreditExhaustedError(error), isTrue);
    });

    test('ignores unrelated errors', () {
      final error = ApiException(
        message: 'Server error',
        statusCode: 500,
        code: 'INTERNAL',
      );
      expect(isCreditExhaustedError(error), isFalse);
    });
  });
}
