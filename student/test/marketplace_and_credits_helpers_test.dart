import 'package:flutter_test/flutter_test.dart';

import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_repository.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
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

    test('defaults to available when key missing on success payload', () {
      final access = MarketplaceAccess.fromJson({});
      expect(access.available, isTrue);
    });

    test('null json fails closed', () {
      final access = MarketplaceAccess.fromJson(null);
      expect(access.available, isFalse);
      expect(access.ready, isTrue);
    });

    test('unknownClosed never grants access', () {
      expect(MarketplaceAccess.unknownClosed.available, isFalse);
      expect(MarketplaceAccess.loading.available, isFalse);
      expect(MarketplaceAccess.loading.ready, isFalse);
    });
  });

  group('MarketplaceAccessService fail-closed', () {
    test('gateway throw → unavailable', () async {
      final service = MarketplaceAccessService(
        gateway: _ThrowingMarketplaceGateway(),
      );
      await service.refresh(force: true);
      expect(service.available, isFalse);
      expect(service.ready, isTrue);
      expect(service.reason, isNotNull);
    });

    test('gateway closed → unavailable', () async {
      final service = MarketplaceAccessService(
        gateway: _FixedMarketplaceGateway(MarketplaceAccess.unknownClosed),
      );
      await service.refresh(force: true);
      expect(service.available, isFalse);
    });

    test('gateway open → available', () async {
      final service = MarketplaceAccessService(
        gateway: _FixedMarketplaceGateway(
          const MarketplaceAccess(available: true),
        ),
      );
      await service.refresh(force: true);
      expect(service.available, isTrue);
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

class _ThrowingMarketplaceGateway implements MarketplaceAccessGateway {
  @override
  Future<MarketplaceAccess> fetch() async {
    throw StateError('network down');
  }
}

class _FixedMarketplaceGateway implements MarketplaceAccessGateway {
  _FixedMarketplaceGateway(this.value);

  final MarketplaceAccess value;

  @override
  Future<MarketplaceAccess> fetch() async => value;
}
