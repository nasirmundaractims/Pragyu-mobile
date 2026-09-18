import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/catalog/data/catalog_checkout_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_checkout_models.dart';
import 'package:student_mobile/features/payments/domain/payments_models.dart';
import 'package:student_mobile/features/payments/presentation/payment_handoff.dart';

/// S-73 Catalog checkout — create order, pay, confirm enrollment.
class CatalogCheckoutScreen extends StatefulWidget {
  const CatalogCheckoutScreen({
    super.key,
    required this.args,
    this.checkoutRepository,
  });

  final CatalogCheckoutArgs args;
  final CatalogCheckoutGateway? checkoutRepository;

  @override
  State<CatalogCheckoutScreen> createState() => _CatalogCheckoutScreenState();
}

class _CatalogCheckoutScreenState extends State<CatalogCheckoutScreen>
    with WidgetsBindingObserver {
  late final CatalogCheckoutGateway _repo =
      widget.checkoutRepository ?? CatalogCheckoutRepository();

  final _couponController = TextEditingController();

  bool _loading = true;
  bool _paying = false;
  bool _confirming = false;
  bool _awaitingHandoff = false;
  Uri? _handoffUri;
  String? _error;
  CatalogCheckoutSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _couponController.text = widget.args.couponCode ?? '';
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _couponController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _awaitingHandoff &&
        !_confirming &&
        !(_snapshot?.order.isPaid ?? false)) {
      _confirm(fromResume: true);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? orderId = widget.args.orderId?.trim();
      if ((orderId == null || orderId.isEmpty) && widget.args.canCreateOrder) {
        final created = await _repo.createOrder(
          programId: widget.args.programId!.trim(),
          courseId: widget.args.courseId!.trim(),
          couponCode: _couponController.text.trim().isEmpty
              ? null
              : _couponController.text.trim(),
        );
        orderId = created.id;
      }
      if (orderId == null || orderId.isEmpty) {
        throw ApiException(
          message:
              'Checkout needs a course offer with program and course ids, or an existing order.',
          statusCode: 0,
        );
      }
      final snapshot = await _repo.loadCheckout(orderId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        if (_isProcessing(snapshot.order)) {
          _awaitingHandoff = true;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to open checkout.';
      });
    }
  }

  static bool _isProcessing(CommerceOrder order) {
    if (order.isPaid) return false;
    final status = (order.paymentStatus ?? order.status ?? '').toLowerCase();
    return status.contains('process') || status == 'awaiting_payment';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pay() async {
    final order = _snapshot?.order;
    if (order == null || _paying) return;
    setState(() => _paying = true);
    try {
      final result = await _repo.payOrder(order.id);
      if (!mounted) return;

      if (result.order.isPaid) {
        setState(() {
          _snapshot = CatalogCheckoutSnapshot(
            order: result.order,
            offer: _snapshot?.offer,
          );
          _awaitingHandoff = false;
        });
        _toast('Payment successful. Enrollment activated.');
        return;
      }

      final session = result.session;
      Uri? handoff;
      if (session?.checkoutUrl != null && session!.checkoutUrl!.isNotEmpty) {
        handoff = Uri.tryParse(session.checkoutUrl!);
      } else if (session?.isRazorpay == true) {
        handoff = _webCheckoutUri(order.id);
        if (handoff == null) {
          _toast(
            'Razorpay checkout needs student-web. Set STUDENT_WEB_BASE_URL, '
            'or finish payment on web and tap Confirm payment.',
          );
          setState(() {
            _snapshot = CatalogCheckoutSnapshot(
              order: result.order,
              offer: _snapshot?.offer,
            );
            _awaitingHandoff = true;
          });
          return;
        }
      }

      if (handoff != null) {
        final proceed = await confirmPaymentHandoff(context);
        if (!mounted) return;
        if (!proceed) return;

        final opened = await launchPaymentHandoff(handoff);
        if (!mounted) return;
        setState(() {
          _handoffUri = handoff;
          _awaitingHandoff = true;
          _snapshot = CatalogCheckoutSnapshot(
            order: result.order,
            offer: _snapshot?.offer,
          );
        });
        if (!opened) {
          _toast('Could not open payment page. Try Open payment again.');
        }
        return;
      }

      setState(() {
        _snapshot = CatalogCheckoutSnapshot(
          order: result.order,
          offer: _snapshot?.offer,
        );
        _awaitingHandoff = true;
      });
      _toast('Payment started. Confirm if the status does not update.');
    } catch (error) {
      if (!mounted) return;
      _toast(error is ApiException ? error.message : 'Payment failed.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Uri? _webCheckoutUri(String orderId) {
    final base = AppConfig.instance.studentWebBaseUrl;
    if (base == null || base.isEmpty) return null;
    return Uri.parse('$base/catalog/checkout/$orderId');
  }

  Future<void> _openHandoffAgain() async {
    final uri = _handoffUri ??
        (_snapshot?.order.id != null
            ? _webCheckoutUri(_snapshot!.order.id)
            : null);
    if (uri == null) {
      _toast('No payment link available. Tap Pay now to start again.');
      return;
    }
    final opened = await launchPaymentHandoff(uri);
    if (!mounted) return;
    if (!opened) {
      _toast('Could not open payment page.');
    }
  }

  Future<void> _confirm({bool fromResume = false}) async {
    final order = _snapshot?.order;
    if (order == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      final paid = await _repo.pollUntilPaid(orderId: order.id);
      if (!mounted) return;
      setState(() {
        _snapshot = CatalogCheckoutSnapshot(
          order: paid,
          offer: _snapshot?.offer,
        );
        if (paid.isPaid) {
          _awaitingHandoff = false;
        }
      });
      if (paid.isPaid) {
        _toast('Payment successful. Enrollment activated.');
      } else if (!fromResume) {
        _toast(
          'Payment is still confirming. Wait a moment and try again.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (!fromResume) {
        _toast(
          error is ApiException
              ? error.message
              : 'Unable to confirm payment.',
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _snapshot?.courseTitle ??
        widget.args.title ??
        'Complete payment';
    final order = _snapshot?.order;
    final showConfirm = order != null &&
        !order.isPaid &&
        (_awaitingHandoff || _isProcessing(order));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Checkout'),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && _snapshot == null
                  ? _ErrorBody(message: _error!, onRetry: _bootstrap)
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _bootstrap,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Review your order and pay securely. You are enrolled only after payment succeeds.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_awaitingHandoff &&
                                order != null &&
                                !order.isPaid) ...[
                              PaymentWaitingBanner(
                                confirming: _confirming,
                                onConfirm: () => _confirm(),
                                onOpenAgain: _openHandoffAgain,
                                onDismiss: () => setState(
                                  () => _awaitingHandoff = false,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (_snapshot != null) ...[
                              _OrderSummaryCard(snapshot: _snapshot!),
                              const SizedBox(height: 14),
                              _PaymentCard(
                                order: _snapshot!.order,
                                paying: _paying,
                                confirming: _confirming,
                                showConfirm: showConfirm && !_awaitingHandoff,
                                onPay: _pay,
                                onConfirm: () => _confirm(),
                                onOpenLearning: () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                  AppRoutes.home,
                                  (route) => false,
                                ),
                                onOpenBilling: () => Navigator.of(context)
                                    .pushNamed(
                                  AppRoutes.payments,
                                  arguments: PaymentsViewId.billing,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.snapshot});

  final CatalogCheckoutSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final order = snapshot.order;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order ${order.orderNumber ?? order.id}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          _kv('Course', snapshot.courseTitle),
          _kv('Status', order.displayStatus),
          _kv('Amount', order.amountLabel),
          _kv(
            'Discount',
            '${order.currency} ${order.discountAmount ?? '0.00'}',
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.order,
    required this.paying,
    required this.confirming,
    required this.showConfirm,
    required this.onPay,
    required this.onConfirm,
    required this.onOpenLearning,
    required this.onOpenBilling,
  });

  final CommerceOrder order;
  final bool paying;
  final bool confirming;
  final bool showConfirm;
  final VoidCallback onPay;
  final VoidCallback onConfirm;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenBilling;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            order.isPaid ? 'Payment completed' : 'Payment',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.isPaid
                ? 'Your enrollment is active.'
                : 'Pay securely with Razorpay (UPI, cards, net banking). Enrollment activates only after payment succeeds.',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (order.isPaid) ...[
            FilledButton(
              onPressed: onOpenLearning,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Open my learning'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenBilling,
              child: const Text('View billing history'),
            ),
          ] else ...[
            FilledButton(
              onPressed: order.canPay && !paying ? onPay : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: Text(paying ? 'Starting…' : 'Pay now'),
            ),
            if (showConfirm) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: confirming ? null : onConfirm,
                child: Text(
                  confirming ? 'Confirming…' : 'Confirm payment',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.catalog),
              child: const Text('Back to catalog'),
            ),
          ],
        ),
      ),
    );
  }
}
