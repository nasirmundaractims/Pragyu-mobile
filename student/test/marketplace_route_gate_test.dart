import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_repository.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
import 'package:student_mobile/features/catalog/domain/marketplace_access_models.dart';
import 'package:student_mobile/features/catalog/presentation/widgets/marketplace_route_gate.dart';

class _FixedGateway implements MarketplaceAccessGateway {
  _FixedGateway(this.value);

  final MarketplaceAccess value;

  @override
  Future<MarketplaceAccess> fetch() async => value;
}

class _ThrowingGateway implements MarketplaceAccessGateway {
  @override
  Future<MarketplaceAccess> fetch() async {
    throw StateError('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gate shows catalog when access available', (tester) async {
    final service = MarketplaceAccessService(
      gateway: _FixedGateway(const MarketplaceAccess(available: true)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MarketplaceRouteGate(
          service: service,
          child: const Scaffold(body: Text('Catalog browse')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catalog browse'), findsOneWidget);
    expect(find.text('Marketplace unavailable'), findsNothing);
  });

  testWidgets('gate shows unavailable when access denied', (tester) async {
    final service = MarketplaceAccessService(
      gateway: _FixedGateway(
        const MarketplaceAccess(
          available: false,
          reason: 'Institute disabled marketplace',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MarketplaceRouteGate(
          service: service,
          child: const Scaffold(body: Text('Catalog browse')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catalog browse'), findsNothing);
    expect(find.text('Marketplace unavailable'), findsOneWidget);
    expect(find.text('Institute disabled marketplace'), findsOneWidget);
  });

  testWidgets('gate fails closed when access check throws', (tester) async {
    final service = MarketplaceAccessService(
      gateway: _ThrowingGateway(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MarketplaceRouteGate(
          service: service,
          child: const Scaffold(body: Text('Catalog browse')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catalog browse'), findsNothing);
    expect(find.text('Marketplace unavailable'), findsOneWidget);
    expect(
      find.text('Marketplace access could not be verified right now.'),
      findsOneWidget,
    );
  });
}
