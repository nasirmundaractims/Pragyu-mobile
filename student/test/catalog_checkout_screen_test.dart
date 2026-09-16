import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/catalog/data/catalog_checkout_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_checkout_models.dart';
import 'package:student_mobile/features/catalog/presentation/screens/catalog_checkout_screen.dart';
import 'package:student_mobile/features/catalog/presentation/screens/catalog_detail_screen.dart';
import 'package:student_mobile/features/catalog/data/catalog_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';

class _FakeCheckout implements CatalogCheckoutGateway {
  _FakeCheckout({
    required this.order,
    this.offer,
    this.payResult,
  });

  CommerceOrder order;
  final CommerceCourseOffer? offer;
  CatalogPayResult? payResult;
  var createCount = 0;
  var confirmCount = 0;

  @override
  Future<CommerceOrder> createOrder({
    required String programId,
    required String courseId,
    String? couponCode,
    String? batchId,
  }) async {
    createCount += 1;
    return order;
  }

  @override
  Future<CatalogCheckoutSnapshot> loadCheckout(String orderId) async {
    return CatalogCheckoutSnapshot(order: order, offer: offer);
  }

  @override
  Future<CatalogPayResult> payOrder(String orderId) async {
    return payResult ??
        CatalogPayResult(
          order: order.copyPaid(),
        );
  }

  @override
  Future<CommerceOrder> confirmPayment({
    required String orderId,
    String? gatewayPaymentId,
  }) async {
    confirmCount += 1;
    order = order.copyPaid();
    return order;
  }

  @override
  Future<CommerceOrder> pollUntilPaid({
    required String orderId,
    String? gatewayPaymentId,
    int attempts = 8,
  }) async {
    return confirmPayment(orderId: orderId);
  }
}

extension on CommerceOrder {
  CommerceOrder copyPaid() => CommerceOrder(
        id: id,
        orderNumber: orderNumber,
        status: 'paid',
        paymentStatus: 'completed',
        currency: currency,
        totalAmount: totalAmount,
        amount: amount,
        discountAmount: discountAmount,
        programId: programId,
        courseId: courseId,
      );
}

class _FakeCatalog implements CatalogGateway {
  _FakeCatalog(this.listing);

  final CatalogListing listing;

  @override
  Future<CatalogSnapshot> loadCatalog({String? query}) async =>
      CatalogSnapshot(items: [listing]);

  @override
  Future<CatalogListing> loadListing(String slug) async => listing;
}

void main() {
  testWidgets('S-73 checkout shows order and pays', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeCheckout(
      order: const CommerceOrder(
        id: 'o1',
        orderNumber: 'ORD-1',
        paymentStatus: 'pending',
        totalAmount: '999.00',
        courseId: 'c1',
      ),
      offer: const CommerceCourseOffer(
        courseId: 'c1',
        courseName: 'GPSC Foundation',
      ),
      payResult: CatalogPayResult(
        order: const CommerceOrder(
          id: 'o1',
          orderNumber: 'ORD-1',
          status: 'paid',
          paymentStatus: 'completed',
          totalAmount: '999.00',
          courseId: 'c1',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CatalogCheckoutScreen(
          args: const CatalogCheckoutArgs(
            programId: 'p1',
            courseId: 'c1',
            title: 'GPSC Foundation',
          ),
          checkoutRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPSC Foundation'), findsWidgets);
    expect(find.text('Pay now'), findsOneWidget);
    expect(fake.createCount, 1);

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();
    expect(find.text('Open my learning'), findsOneWidget);
  });

  testWidgets('S-73 detail shows Buy / Enroll when commerce ids exist',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CatalogDetailScreen(
          slug: 'gpsc',
          catalogRepository: _FakeCatalog(
            const CatalogListing(
              id: 'l1',
              slug: 'gpsc',
              title: 'GPSC Pack',
              price: 499,
              currency: 'INR',
              programId: 'p1',
              courseId: 'c1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy / Enroll'), findsOneWidget);
    expect(find.textContaining('not linked to a purchasable'), findsNothing);
  });
}
