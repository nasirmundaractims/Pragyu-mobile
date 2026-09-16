import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/payments/domain/payments_models.dart';

void main() {
  test('PaymentsViewId parses aliases', () {
    expect(PaymentsViewIdX.fromObject('billing'), PaymentsViewId.billing);
    expect(PaymentsViewIdX.fromObject('credits'), PaymentsViewId.balance);
    expect(PaymentsViewIdX.fromObject({'view': 'dues'}), PaymentsViewId.fees);
  });

  test('FeeAssignment detects payable outstanding', () {
    final payable = FeeAssignment.fromJson({
      'id': 'a1',
      'status': 'active',
      'schedule_type': 'installment',
      'currency': 'INR',
      'total_amount': '1000',
      'outstanding': {'outstanding': '250'},
      'installments': [
        {
          'id': 'i1',
          'label': 'Sep',
          'due_date': '2026-09-30',
          'amount_due': '250',
          'status': 'due',
        },
      ],
    });
    expect(payable.isPayable, isTrue);
    expect(payable.installments.first.title, 'Sep');
  });
}
