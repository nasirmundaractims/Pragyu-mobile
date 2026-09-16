import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/catalog/domain/catalog_checkout_models.dart';

abstract class CatalogCheckoutGateway {
  Future<CommerceOrder> createOrder({
    required String programId,
    required String courseId,
    String? couponCode,
    String? batchId,
  });

  Future<CatalogCheckoutSnapshot> loadCheckout(String orderId);

  Future<CatalogPayResult> payOrder(String orderId);

  Future<CommerceOrder> confirmPayment({
    required String orderId,
    String? gatewayPaymentId,
  });

  Future<CommerceOrder> pollUntilPaid({
    required String orderId,
    String? gatewayPaymentId,
    int attempts = 8,
  });
}

class CatalogCheckoutRepository implements CatalogCheckoutGateway {
  CatalogCheckoutRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<CommerceOrder> createOrder({
    required String programId,
    required String courseId,
    String? couponCode,
    String? batchId,
  }) async {
    final session = await _requireSession();
    final body = <String, dynamic>{
      'program_id': programId,
      'course_id': courseId,
      'plan': 'standard',
    };
    final coupon = couponCode?.trim();
    if (coupon != null && coupon.isNotEmpty) {
      body['coupon_code'] = coupon;
    }
    final batch = batchId?.trim();
    if (batch != null && batch.isNotEmpty) {
      body['batch_id'] = batch;
    }

    final envelope = await _api.post(
      '/students/me/commerce/checkout',
      body: body,
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final order = CommerceOrder.fromJson(_asMap(envelope['data']));
    if (order.id.isEmpty) {
      throw ApiException(
        message: 'Unable to create checkout order.',
        statusCode: 0,
      );
    }
    return order;
  }

  @override
  Future<CatalogCheckoutSnapshot> loadCheckout(String orderId) async {
    final session = await _requireSession();
    final envelope = await _api.get(
      '/students/me/commerce/orders/$orderId',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final order = CommerceOrder.fromJson(_asMap(envelope['data']));
    if (order.id.isEmpty) {
      throw ApiException(
        message: 'Order not found.',
        statusCode: 404,
      );
    }

    CommerceCourseOffer? offer;
    final courseId = order.courseId;
    if (courseId != null && courseId.isNotEmpty) {
      try {
        final offerEnvelope = await _api.get(
          '/students/me/commerce/courses/$courseId',
          accessToken: session.accessToken,
          organizationId: session.organizationId,
        );
        offer = CommerceCourseOffer.fromJson(_asMap(offerEnvelope['data']));
      } catch (_) {}
    }

    return CatalogCheckoutSnapshot(order: order, offer: offer);
  }

  @override
  Future<CatalogPayResult> payOrder(String orderId) async {
    final session = await _requireSession();
    final envelope = await _api.post(
      '/students/me/commerce/orders/$orderId/pay',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final data = _asMap(envelope['data']);
    final order = CommerceOrder.fromJson(data);
    final sessionMap = _asMap(data['checkout_session']);
    final metaSession = _asMap(_asMap(data['metadata'])['checkout_session']);
    final hosted = sessionMap.isNotEmpty
        ? HostedCheckoutSession.fromJson(sessionMap)
        : metaSession.isNotEmpty
            ? HostedCheckoutSession.fromJson(metaSession)
            : null;
    return CatalogPayResult(order: order, session: hosted);
  }

  @override
  Future<CommerceOrder> confirmPayment({
    required String orderId,
    String? gatewayPaymentId,
  }) async {
    final session = await _requireSession();
    final body = <String, dynamic>{};
    if (gatewayPaymentId != null && gatewayPaymentId.isNotEmpty) {
      body['gateway_payment_id'] = gatewayPaymentId;
    }
    final envelope = await _api.post(
      '/students/me/commerce/orders/$orderId/confirm-payment',
      body: body.isEmpty ? null : body,
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return CommerceOrder.fromJson(_asMap(envelope['data']));
  }

  @override
  Future<CommerceOrder> pollUntilPaid({
    required String orderId,
    String? gatewayPaymentId,
    int attempts = 8,
  }) async {
    CommerceOrder? latest;
    for (var i = 0; i < attempts; i++) {
      try {
        latest = await confirmPayment(
          orderId: orderId,
          gatewayPaymentId: gatewayPaymentId,
        );
        if (latest.isPaid) return latest;
        if (['failed', 'cancelled'].contains(latest.status.toLowerCase())) {
          return latest;
        }
      } catch (_) {
        try {
          final snapshot = await loadCheckout(orderId);
          latest = snapshot.order;
          if (latest.isPaid) return latest;
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    return latest ??
        (await loadCheckout(orderId)).order;
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
