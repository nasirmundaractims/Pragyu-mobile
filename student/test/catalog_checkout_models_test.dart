import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/catalog/domain/catalog_checkout_models.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';

void main() {
  test('CatalogListing parses commerce ids for checkout', () {
    final listing = CatalogListing.fromJson({
      'id': 'l1',
      'slug': 'gpsc-course',
      'title': 'GPSC Course',
      'program_id': 'p1',
      'course_id': 'c1',
      'price': 999,
      'currency': 'INR',
    });
    expect(listing.canCheckout, isTrue);
    expect(listing.programId, 'p1');
    expect(listing.courseId, 'c1');
  });

  test('CommerceOrder paid and canPay flags', () {
    final pending = CommerceOrder.fromJson({
      'id': 'o1',
      'payment_status': 'pending',
      'status': 'open',
      'total_amount': '999',
      'currency': 'INR',
    });
    expect(pending.canPay, isTrue);
    expect(pending.isPaid, isFalse);

    final paid = CommerceOrder.fromJson({
      'id': 'o2',
      'payment_status': 'completed',
      'status': 'paid',
    });
    expect(paid.isPaid, isTrue);
    expect(paid.canPay, isFalse);
  });

  test('CatalogCheckoutArgs fromObject', () {
    final args = CatalogCheckoutArgs.fromObject({
      'program_id': 'p1',
      'course_id': 'c1',
      'title': 'Course',
    });
    expect(args.canCreateOrder, isTrue);
    expect(args.hasOrderId, isFalse);
  });
}
