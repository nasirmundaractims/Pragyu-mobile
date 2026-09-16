/// S-72 Payments & AI Balance models.

enum PaymentsViewId { fees, billing, balance }

extension PaymentsViewIdX on PaymentsViewId {
  String get label {
    switch (this) {
      case PaymentsViewId.fees:
        return 'Fees';
      case PaymentsViewId.billing:
        return 'Billing';
      case PaymentsViewId.balance:
        return 'AI Balance';
    }
  }

  String get description {
    switch (this) {
      case PaymentsViewId.fees:
        return 'Tuition and installments';
      case PaymentsViewId.billing:
        return 'Course and plan invoices';
      case PaymentsViewId.balance:
        return 'Credits left and usage';
    }
  }

  static PaymentsViewId fromObject(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    if (raw is PaymentsViewId) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return fromObject(map['view'] ?? map['tab']);
    }
    switch (value) {
      case 'billing':
      case 'invoices':
      case 'plan':
        return PaymentsViewId.billing;
      case 'balance':
      case 'ai':
      case 'ai-usage':
      case 'credits':
        return PaymentsViewId.balance;
      case 'fees':
      case 'dues':
      default:
        return PaymentsViewId.fees;
    }
  }
}

class FeeDuesSummary {
  const FeeDuesSummary({
    this.currency = 'INR',
    this.totalDue = '0.00',
    this.totalPaid = '0.00',
    this.totalWaived = '0.00',
    this.outstanding = '0.00',
    this.openCount = 0,
  });

  final String currency;
  final String totalDue;
  final String totalPaid;
  final String totalWaived;
  final String outstanding;
  final int openCount;

  double get outstandingValue => double.tryParse(outstanding) ?? 0;

  factory FeeDuesSummary.fromJson(Map<String, dynamic> json) {
    return FeeDuesSummary(
      currency: (json['currency'] ?? 'INR').toString(),
      totalDue: (json['total_due'] ?? '0.00').toString(),
      totalPaid: (json['total_paid'] ?? '0.00').toString(),
      totalWaived: (json['total_waived'] ?? '0.00').toString(),
      outstanding: (json['outstanding'] ?? '0.00').toString(),
      openCount: _int(json['open_count']) ?? 0,
    );
  }
}

class FeeInstallment {
  const FeeInstallment({
    required this.id,
    this.label,
    this.sequenceNo,
    this.dueDate,
    this.amountDue,
    this.amountPaid,
    this.status,
  });

  final String id;
  final String? label;
  final int? sequenceNo;
  final String? dueDate;
  final String? amountDue;
  final String? amountPaid;
  final String? status;

  String get title =>
      (label?.trim().isNotEmpty == true) ? label! : 'Installment ${sequenceNo ?? ''}';

  factory FeeInstallment.fromJson(Map<String, dynamic> json) {
    return FeeInstallment(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString(),
      sequenceNo: _int(json['sequence_no']),
      dueDate: json['due_date']?.toString(),
      amountDue: json['amount_due']?.toString(),
      amountPaid: json['amount_paid']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class FeeAssignment {
  const FeeAssignment({
    required this.id,
    this.scheduleType = '',
    this.status = '',
    this.currency = 'INR',
    this.totalAmount,
    this.outstandingAmount,
    this.installments = const [],
  });

  final String id;
  final String scheduleType;
  final String status;
  final String currency;
  final String? totalAmount;
  final String? outstandingAmount;
  final List<FeeInstallment> installments;

  bool get isPayable {
    final outstanding = double.tryParse(outstandingAmount ?? '') ?? 0;
    return status.toLowerCase() == 'active' && outstanding > 0;
  }

  factory FeeAssignment.fromJson(Map<String, dynamic> json) {
    final outstanding = _asMap(json['outstanding']);
    final installmentsRaw = json['installments'];
    final installments = <FeeInstallment>[];
    if (installmentsRaw is List) {
      for (final row in installmentsRaw) {
        if (row is! Map) continue;
        installments.add(
          FeeInstallment.fromJson(
            row.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      }
    }
    return FeeAssignment(
      id: json['id']?.toString() ?? '',
      scheduleType: (json['schedule_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      totalAmount: json['total_amount']?.toString(),
      outstandingAmount:
          (outstanding['outstanding'] ?? json['outstanding'])?.toString(),
      installments: installments,
    );
  }
}

class FeePaymentRecord {
  const FeePaymentRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.method,
    this.paidAt,
  });

  final String id;
  final String amount;
  final String currency;
  final String status;
  final String? method;
  final DateTime? paidAt;

  bool get isCompleted => status.toLowerCase() == 'completed';

  String get title =>
      '$currency $amount${method == null || method!.isEmpty ? '' : ' · $method'}';

  factory FeePaymentRecord.fromJson(Map<String, dynamic> json) {
    return FeePaymentRecord(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? '0').toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      status: (json['status'] ?? '').toString(),
      method: json['method']?.toString(),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
    );
  }
}

class FeesTabSnapshot {
  const FeesTabSnapshot({
    this.moduleEnabled = false,
    this.paymentsEnabled = false,
    this.settingsUnavailable = false,
    this.missingProfile = false,
    this.dues = const FeeDuesSummary(),
    this.assignments = const [],
    this.payments = const [],
  });

  final bool moduleEnabled;
  final bool paymentsEnabled;
  final bool settingsUnavailable;
  final bool missingProfile;
  final FeeDuesSummary dues;
  final List<FeeAssignment> assignments;
  final List<FeePaymentRecord> payments;

  FeeAssignment? get payableAssignment {
    for (final item in assignments) {
      if (item.isPayable) return item;
    }
    return null;
  }

  List<FeePaymentRecord> get completedPayments =>
      payments.where((p) => p.isCompleted).toList(growable: false);
}

enum BillingRowKind { course, subscription, credits }

class BillingHistoryRow {
  const BillingHistoryRow({
    required this.id,
    required this.kind,
    required this.title,
    required this.amountLabel,
    required this.status,
    required this.whenLabel,
    this.invoiceNumber,
    this.sortableWhen,
  });

  final String id;
  final BillingRowKind kind;
  final String title;
  final String amountLabel;
  final String status;
  final String whenLabel;
  final String? invoiceNumber;
  final DateTime? sortableWhen;
}

class BillingTabSnapshot {
  const BillingTabSnapshot({this.rows = const []});

  final List<BillingHistoryRow> rows;
}

class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    this.credits,
    this.priceAmount,
    this.currency = 'INR',
  });

  final String id;
  final String name;
  final int? credits;
  final String? priceAmount;
  final String currency;

  String get priceLabel {
    if (priceAmount == null) return '';
    return '$priceAmount ${currency.toUpperCase()}';
  }

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? 'Credit pack').toString(),
      credits: _int(json['credits']),
      priceAmount: json['price_amount']?.toString(),
      currency: (json['currency'] ?? 'INR').toString(),
    );
  }
}

class CreditUsageRow {
  const CreditUsageRow({
    required this.id,
    required this.label,
    required this.credits,
    this.at,
  });

  final String id;
  final String label;
  final double credits;
  final DateTime? at;

  factory CreditUsageRow.fromJson(Map<String, dynamic> json) {
    return CreditUsageRow(
      id: json['id']?.toString() ?? '',
      label: (json['reference_type'] ??
              json['feature_key'] ??
              json['credit_type'] ??
              'other')
          .toString(),
      credits: _num(json['credits_consumed'] ?? json['amount']) ?? 0,
      at: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class AiBalanceTabSnapshot {
  const AiBalanceTabSnapshot({
    this.ai = 0,
    this.evaluation = 0,
    this.ocr = 0,
    this.used = 0,
    this.packages = const [],
    this.usage = const [],
    this.featureBreakdown = const [],
  });

  final double ai;
  final double evaluation;
  final double ocr;
  final double used;
  final List<CreditPackage> packages;
  final List<CreditUsageRow> usage;
  final List<({String label, double credits})> featureBreakdown;

  double get available => ai + evaluation + ocr;
  double get given => available + used;
  bool get isEmptyWallet => available <= 0;
}

class PaymentsSnapshot {
  const PaymentsSnapshot({
    this.fees = const FeesTabSnapshot(),
    this.billing = const BillingTabSnapshot(),
    this.balance = const AiBalanceTabSnapshot(),
  });

  final FeesTabSnapshot fees;
  final BillingTabSnapshot billing;
  final AiBalanceTabSnapshot balance;
}

class PaymentCheckoutResult {
  const PaymentCheckoutResult({
    required this.paymentId,
    required this.status,
    this.checkoutUrl,
  });

  final String paymentId;
  final String status;
  final String? checkoutUrl;

  bool get isCompleted => status.toLowerCase() == 'completed';
}

String formatMoney(String? currency, Object? amount) =>
    '${currency ?? 'INR'} ${amount ?? '—'}';

String formatWhen(DateTime? value) {
  if (value == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = value.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

Map<String, dynamic> asSettingsMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

Map<String, dynamic> _asMap(Object? raw) => asSettingsMap(raw);

int? _int(Object? raw) {
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

double? _num(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}
