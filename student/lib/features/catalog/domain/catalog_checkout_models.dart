/// S-73 Catalog checkout / enroll models.

class CatalogCheckoutArgs {
  const CatalogCheckoutArgs({
    this.orderId,
    this.programId,
    this.courseId,
    this.title,
    this.couponCode,
  });

  final String? orderId;
  final String? programId;
  final String? courseId;
  final String? title;
  final String? couponCode;

  bool get hasOrderId => orderId?.trim().isNotEmpty == true;
  bool get canCreateOrder =>
      programId?.trim().isNotEmpty == true &&
      courseId?.trim().isNotEmpty == true;

  factory CatalogCheckoutArgs.fromObject(Object? raw) {
    if (raw is CatalogCheckoutArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return CatalogCheckoutArgs(
        orderId: map['orderId']?.toString() ?? map['order_id']?.toString(),
        programId:
            map['programId']?.toString() ?? map['program_id']?.toString(),
        courseId: map['courseId']?.toString() ?? map['course_id']?.toString(),
        title: map['title']?.toString(),
        couponCode:
            map['couponCode']?.toString() ?? map['coupon_code']?.toString(),
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return CatalogCheckoutArgs(orderId: raw);
    }
    return const CatalogCheckoutArgs();
  }
}

class CommerceOrder {
  const CommerceOrder({
    required this.id,
    this.orderNumber,
    this.status = 'pending',
    this.paymentStatus = 'pending',
    this.currency = 'INR',
    this.totalAmount,
    this.amount,
    this.discountAmount,
    this.programId,
    this.courseId,
    this.failureReason,
  });

  final String id;
  final String? orderNumber;
  final String status;
  final String paymentStatus;
  final String currency;
  final String? totalAmount;
  final String? amount;
  final String? discountAmount;
  final String? programId;
  final String? courseId;
  final String? failureReason;

  bool get isPaid =>
      paymentStatus.toLowerCase() == 'completed' ||
      status.toLowerCase() == 'paid';

  bool get canPay {
    if (isPaid) return false;
    final statusValue = paymentStatus.toLowerCase();
    return statusValue.isEmpty ||
        statusValue == 'pending' ||
        statusValue == 'processing' ||
        statusValue == 'failed';
  }

  String get amountLabel =>
      '$currency ${totalAmount ?? amount ?? '0.00'}';

  String get displayStatus =>
      (paymentStatus.isNotEmpty ? paymentStatus : status).toLowerCase();

  factory CommerceOrder.fromJson(Map<String, dynamic> json) {
    return CommerceOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      paymentStatus: (json['payment_status'] ?? 'pending').toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      totalAmount: json['total_amount']?.toString(),
      amount: json['amount']?.toString(),
      discountAmount: json['discount_amount']?.toString(),
      programId: json['program_id']?.toString(),
      courseId: json['course_id']?.toString(),
      failureReason: json['failure_reason']?.toString(),
    );
  }
}

class CommerceCourseOffer {
  const CommerceCourseOffer({
    this.courseId,
    this.courseName,
    this.currency = 'INR',
    this.price,
  });

  final String? courseId;
  final String? courseName;
  final String currency;
  final String? price;

  factory CommerceCourseOffer.fromJson(Map<String, dynamic> json) {
    return CommerceCourseOffer(
      courseId: json['id']?.toString() ?? json['course_id']?.toString(),
      courseName: (json['course_name'] ?? json['name'] ?? json['title'])
          ?.toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      price: (json['price'] ?? json['amount'] ?? json['total_amount'])
          ?.toString(),
    );
  }
}

class HostedCheckoutSession {
  const HostedCheckoutSession({
    this.provider,
    this.publicKey,
    this.orderRef,
    this.amount,
    this.currency,
    this.checkoutUrl,
  });

  final String? provider;
  final String? publicKey;
  final String? orderRef;
  final num? amount;
  final String? currency;
  final String? checkoutUrl;

  bool get isRazorpay =>
      (provider ?? '').toLowerCase() == 'razorpay' &&
      publicKey != null &&
      orderRef != null;

  factory HostedCheckoutSession.fromJson(Map<String, dynamic> json) {
    return HostedCheckoutSession(
      provider: json['provider']?.toString(),
      publicKey: json['public_key']?.toString(),
      orderRef: json['order_ref']?.toString(),
      amount: json['amount'] is num
          ? json['amount'] as num
          : num.tryParse(json['amount']?.toString() ?? ''),
      currency: json['currency']?.toString(),
      checkoutUrl: (json['checkout_url'] ?? json['url'])?.toString(),
    );
  }
}

class CatalogPayResult {
  const CatalogPayResult({
    required this.order,
    this.session,
  });

  final CommerceOrder order;
  final HostedCheckoutSession? session;
}

class CatalogCheckoutSnapshot {
  const CatalogCheckoutSnapshot({
    required this.order,
    this.offer,
  });

  final CommerceOrder order;
  final CommerceCourseOffer? offer;

  String get courseTitle =>
      offer?.courseName?.trim().isNotEmpty == true
          ? offer!.courseName!
          : 'Course enrollment';
}
