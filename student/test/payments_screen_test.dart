import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/payments/data/payments_repository.dart';
import 'package:student_mobile/features/payments/domain/payments_models.dart';
import 'package:student_mobile/features/payments/presentation/screens/payments_screen.dart';

class _FakePayments implements PaymentsGateway {
  _FakePayments(this.snapshot);

  PaymentsSnapshot snapshot;
  String? paidAssignmentId;
  String? purchasedPackageId;

  @override
  Future<PaymentsSnapshot> loadHub() async => snapshot;

  @override
  Future<PaymentCheckoutResult> payFeeAssignment(String assignmentId) async {
    paidAssignmentId = assignmentId;
    return const PaymentCheckoutResult(
      paymentId: 'pay-1',
      status: 'completed',
    );
  }

  @override
  Future<void> sendFeeReceipt({
    required String paymentId,
    required List<String> channels,
  }) async {}

  @override
  Future<void> purchaseCreditPack(String packageId) async {
    purchasedPackageId = packageId;
  }
}

void main() {
  testWidgets('S-72 fees tab shows dues and pay now', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakePayments(
      const PaymentsSnapshot(
        fees: FeesTabSnapshot(
          moduleEnabled: true,
          paymentsEnabled: true,
          dues: FeeDuesSummary(
            currency: 'INR',
            outstanding: '500.00',
            totalDue: '1000.00',
            totalPaid: '500.00',
          ),
          assignments: [
            FeeAssignment(
              id: 'asg-1',
              scheduleType: 'installment',
              status: 'active',
              outstandingAmount: '500.00',
            ),
          ],
          payments: [
            FeePaymentRecord(
              id: 'pay-1',
              amount: '500.00',
              currency: 'INR',
              status: 'completed',
              method: 'upi',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PaymentsScreen(paymentsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Outstanding dues'), findsOneWidget);
    expect(find.text('Pay now'), findsOneWidget);
    expect(find.textContaining('INR 500'), findsWidgets);

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();
    expect(fake.paidAssignmentId, 'asg-1');
  });

  testWidgets('S-72 balance tab can purchase pack', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakePayments(
      const PaymentsSnapshot(
        balance: AiBalanceTabSnapshot(
          ai: 0,
          packages: [
            CreditPackage(
              id: 'pkg-1',
              name: 'Starter pack',
              credits: 100,
              priceAmount: '199',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PaymentsScreen(
          paymentsRepository: fake,
          initialView: PaymentsViewId.balance,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You are out of AI credits'), findsOneWidget);
    expect(find.text('Starter pack'), findsOneWidget);
    await tester.tap(find.text('Starter pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Purchase selected pack'));
    await tester.pumpAndSettle();
    expect(fake.purchasedPackageId, 'pkg-1');
  });

  testWidgets('S-72 billing empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PaymentsScreen(
          paymentsRepository: _FakePayments(const PaymentsSnapshot()),
          initialView: PaymentsViewId.billing,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payments & invoices'), findsOneWidget);
    expect(find.textContaining('No payments yet'), findsOneWidget);
    expect(find.text('Browse catalog'), findsOneWidget);
  });
}
