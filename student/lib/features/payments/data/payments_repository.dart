import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/payments/domain/payments_models.dart';

abstract class PaymentsGateway {
  Future<PaymentsSnapshot> loadHub();
  Future<PaymentCheckoutResult> payFeeAssignment(String assignmentId);
  Future<void> sendFeeReceipt({
    required String paymentId,
    required List<String> channels,
  });
  Future<void> purchaseCreditPack(String packageId);
}

class PaymentsRepository implements PaymentsGateway {
  PaymentsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<PaymentsSnapshot> loadHub() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);

    final feesFuture = _loadFees(session, profileId);
    final billingFuture = _loadBilling(session);
    final balanceFuture = _loadBalance(session);

    return PaymentsSnapshot(
      fees: await feesFuture,
      billing: await billingFuture,
      balance: await balanceFuture,
    );
  }

  @override
  Future<PaymentCheckoutResult> payFeeAssignment(String assignmentId) async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Student profile required to pay fees.',
        statusCode: 0,
      );
    }

    final envelope = await _api.post(
      '/student-accounts/students/$profileId/payments',
      body: {
        'fee_assignment_id': assignmentId,
        'idempotency_key':
            'mobile-$assignmentId-${DateTime.now().millisecondsSinceEpoch}',
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final data = _asMap(envelope['data']);
    final checkout = _asMap(data['checkout_session']);
    final url = (checkout['checkout_url'] ?? checkout['url'])?.toString();
    return PaymentCheckoutResult(
      paymentId: data['id']?.toString() ?? '',
      status: (data['status'] ?? '').toString(),
      checkoutUrl: (url != null && url.isNotEmpty) ? url : null,
    );
  }

  @override
  Future<void> sendFeeReceipt({
    required String paymentId,
    required List<String> channels,
  }) async {
    final session = await _requireSession();
    await _api.post(
      '/student-accounts/payments/$paymentId/receipt/send',
      body: {'channels': channels},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> purchaseCreditPack(String packageId) async {
    final session = await _requireSession();
    await _api.post(
      '/credits/purchase',
      body: {'package_id': packageId},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<FeesTabSnapshot> _loadFees(
    SessionContext session,
    String? profileId,
  ) async {
    if (profileId == null || profileId.isEmpty) {
      return const FeesTabSnapshot(missingProfile: true);
    }

    Map<String, dynamic> settings = const {};
    try {
      final envelope = await _api.get(
        '/student-accounts/settings',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      settings = _asMap(envelope['data']);
    } catch (_) {
      return const FeesTabSnapshot(settingsUnavailable: true);
    }

    final moduleEnabled = settings['enabled'] == true;
    final paymentsEnabled = settings['payments_enabled'] == true;
    if (!moduleEnabled) {
      return FeesTabSnapshot(
        moduleEnabled: false,
        paymentsEnabled: paymentsEnabled,
      );
    }

    FeeDuesSummary dues = const FeeDuesSummary();
    try {
      final envelope = await _api.get(
        '/student-accounts/students/$profileId/dues',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      dues = FeeDuesSummary.fromJson(_asMap(data['summary']));
    } catch (_) {}

    final assignments = <FeeAssignment>[];
    try {
      final envelope = await _api.get(
        '/student-accounts/students/$profileId/ledger',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      final rows = data['assignments'];
      if (rows is List) {
        for (final row in rows) {
          if (row is! Map) continue;
          final item = FeeAssignment.fromJson(
            row.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (item.id.isNotEmpty) assignments.add(item);
        }
      }
    } catch (_) {}

    final payments = <FeePaymentRecord>[];
    try {
      final envelope = await _api.get(
        '/student-accounts/students/$profileId/payments',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      final list = data is List ? data : _asMap(data)['payments'];
      if (list is List) {
        for (final row in list) {
          if (row is! Map) continue;
          final item = FeePaymentRecord.fromJson(
            row.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (item.id.isNotEmpty) payments.add(item);
        }
      }
    } catch (_) {}

    return FeesTabSnapshot(
      moduleEnabled: true,
      paymentsEnabled: paymentsEnabled,
      dues: dues,
      assignments: assignments,
      payments: payments,
    );
  }

  Future<BillingTabSnapshot> _loadBilling(SessionContext session) async {
    final courseFuture = _listMaps(session, '/students/me/commerce/orders');
    final invoicesFuture = _listMaps(session, '/billing/invoices');
    final creditsFuture = _listMaps(
      session,
      '/credits/transactions',
      query: const {'limit': '50'},
    );

    final courseOrders = await courseFuture;
    final invoices = await invoicesFuture;
    final creditTx = await creditsFuture;

    final rows = <BillingHistoryRow>[];

    for (final order in courseOrders) {
      final status =
          (order['payment_status'] ?? order['status'] ?? '').toString();
      if (status.toLowerCase() != 'completed') continue;
      final when = DateTime.tryParse(
            order['paid_at']?.toString() ?? '',
          ) ??
          DateTime.tryParse(order['created_at']?.toString() ?? '');
      rows.add(
        BillingHistoryRow(
          id: order['id']?.toString() ?? '',
          kind: BillingRowKind.course,
          title:
              'Course enrollment · ${order['order_number'] ?? order['id'] ?? ''}',
          amountLabel: formatMoney(
            order['currency']?.toString(),
            order['total_amount'] ?? order['amount'],
          ),
          status: status,
          whenLabel: formatWhen(when),
          invoiceNumber: order['invoice_number']?.toString(),
          sortableWhen: when,
        ),
      );
    }

    for (final invoice in invoices) {
      final when = DateTime.tryParse(invoice['issued_at']?.toString() ?? '') ??
          DateTime.tryParse(invoice['paid_at']?.toString() ?? '') ??
          DateTime.tryParse(invoice['created_at']?.toString() ?? '');
      rows.add(
        BillingHistoryRow(
          id: invoice['id']?.toString() ?? '',
          kind: BillingRowKind.subscription,
          title:
              'AI / subscription · ${invoice['invoice_number'] ?? invoice['id'] ?? ''}',
          amountLabel: formatMoney(
            invoice['currency']?.toString(),
            invoice['total_amount'] ?? invoice['amount'],
          ),
          status: (invoice['status'] ?? 'issued').toString(),
          whenLabel: formatWhen(when),
          invoiceNumber: invoice['invoice_number']?.toString(),
          sortableWhen: when,
        ),
      );
    }

    for (final tx in creditTx) {
      final type =
          (tx['type'] ?? tx['transaction_type'] ?? tx['entry_type'] ?? '')
              .toString()
              .toLowerCase();
      if (!(type.contains('purchase') ||
          type.contains('credit_pack') ||
          type == 'purchase')) {
        continue;
      }
      final when = DateTime.tryParse(tx['created_at']?.toString() ?? '') ??
          DateTime.tryParse(tx['purchased_at']?.toString() ?? '');
      rows.add(
        BillingHistoryRow(
          id: tx['id']?.toString() ?? '',
          kind: BillingRowKind.credits,
          title:
              'AI credits purchase · ${tx['reference'] ?? tx['package_name'] ?? tx['id'] ?? ''}',
          amountLabel: formatMoney(
            tx['currency']?.toString() ?? 'INR',
            tx['amount_paid'] ?? tx['total_amount'] ?? tx['amount'],
          ),
          status: (tx['status'] ?? 'completed').toString(),
          whenLabel: formatWhen(when),
          sortableWhen: when,
        ),
      );
    }

    rows.sort((a, b) {
      final aMs = a.sortableWhen?.millisecondsSinceEpoch ?? 0;
      final bMs = b.sortableWhen?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });

    return BillingTabSnapshot(rows: rows);
  }

  Future<AiBalanceTabSnapshot> _loadBalance(SessionContext session) async {
    Map<String, dynamic> wallet = const {};
    Map<String, dynamic> summary = const {};
    try {
      final envelope = await _api.get(
        '/credits/wallet',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      wallet = _asMap(envelope['data']);
    } catch (_) {}

    try {
      final envelope = await _api.get(
        '/credits/usage/summary',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      summary = _asMap(envelope['data']);
    } catch (_) {}

    final usageRows = await _listMaps(
      session,
      '/credits/usage',
      query: const {'limit': '100'},
    );
    final usage = usageRows
        .map(CreditUsageRow.fromJson)
        .where((row) => row.id.isNotEmpty || row.credits > 0)
        .toList(growable: false);

    final packageRows = await _listMaps(session, '/credits/packages');
    final packages = packageRows
        .map(CreditPackage.fromJson)
        .where((pkg) => pkg.id.isNotEmpty)
        .toList(growable: false);

    final breakdownMap = <String, double>{};
    for (final row in usage) {
      breakdownMap[row.label] = (breakdownMap[row.label] ?? 0) + row.credits;
    }
    final breakdown = breakdownMap.entries
        .map((e) => (label: e.key, credits: e.value))
        .toList(growable: false)
      ..sort((a, b) => b.credits.compareTo(a.credits));

    return AiBalanceTabSnapshot(
      ai: _num(wallet['ai_balance'] ??
              wallet['remaining_credits'] ??
              wallet['remaining']) ??
          0,
      evaluation: _num(wallet['evaluation_balance']) ?? 0,
      ocr: _num(wallet['ocr_balance']) ?? 0,
      used: _num(summary['total']) ?? 0,
      packages: packages,
      usage: usage.take(20).toList(growable: false),
      featureBreakdown: breakdown.take(6).toList(growable: false),
    );
  }

  Future<List<Map<String, dynamic>>> _listMaps(
    SessionContext session,
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final envelope = await _api.get(
        path,
        query: query,
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
      final nested = _asMap(data)['items'] ?? _asMap(data)['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _loadStudentProfileId(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final id = _asMap(envelope['data'])['id']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    } catch (_) {
      return null;
    }
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  Map<String, dynamic> _asMap(Object? raw) => asSettingsMap(raw);

  double? _num(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }
}
