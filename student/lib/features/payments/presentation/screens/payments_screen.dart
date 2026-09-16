import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/payments/data/payments_repository.dart';
import 'package:student_mobile/features/payments/domain/payments_models.dart';

/// S-72 Payments — fees, billing history, and AI credit balance.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    this.paymentsRepository,
    this.initialView = PaymentsViewId.fees,
  });

  final PaymentsGateway? paymentsRepository;
  final PaymentsViewId initialView;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final PaymentsGateway _repo =
      widget.paymentsRepository ?? PaymentsRepository();

  bool _loading = true;
  bool _paying = false;
  bool _purchasing = false;
  String? _receiptBusyId;
  String? _error;
  String? _selectedPackageId;
  late PaymentsViewId _view;
  PaymentsSnapshot _snapshot = const PaymentsSnapshot();

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _repo.loadHub();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load payments.';
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _payNow() async {
    final assignment = _snapshot.fees.payableAssignment;
    if (assignment == null || _paying) return;
    setState(() => _paying = true);
    try {
      final result = await _repo.payFeeAssignment(assignment.id);
      if (!mounted) return;
      if (result.checkoutUrl != null) {
        final uri = Uri.tryParse(result.checkoutUrl!);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _toast('Payment initiated. Complete checkout with your institute gateway.');
        }
      } else if (result.isCompleted) {
        _toast('Payment completed. You can send a receipt below.');
      } else {
        _toast('Payment initiated.');
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException ? error.message : 'Could not start payment.',
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _sendReceipt(String paymentId, List<String> channels) async {
    setState(() => _receiptBusyId = paymentId);
    try {
      await _repo.sendFeeReceipt(paymentId: paymentId, channels: channels);
      if (!mounted) return;
      _toast('Receipt send requested (${channels.join(' + ')}).');
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException ? error.message : 'Could not send receipt.',
      );
    } finally {
      if (mounted) setState(() => _receiptBusyId = null);
    }
  }

  Future<void> _purchasePack() async {
    final packageId = _selectedPackageId;
    if (packageId == null || _purchasing) return;
    setState(() => _purchasing = true);
    try {
      await _repo.purchaseCreditPack(packageId);
      if (!mounted) return;
      _toast('AI credits added to your wallet.');
      setState(() => _selectedPackageId = null);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(
        error is ApiException ? error.message : 'Unable to purchase credits.',
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Payments'),
        ),
        body: SafeArea(
          child: _loading && _error == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _error != null && !_loading
                  ? _ErrorBody(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Fees, invoices, and AI credits — switch tabs to manage each area.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ViewTabs(
                              selected: _view,
                              onChanged: (view) => setState(() => _view = view),
                            ),
                            const SizedBox(height: 16),
                            if (_view == PaymentsViewId.fees)
                              _FeesPanel(
                                fees: _snapshot.fees,
                                paying: _paying,
                                receiptBusyId: _receiptBusyId,
                                onPayNow: _payNow,
                                onSendReceipt: _sendReceipt,
                              )
                            else if (_view == PaymentsViewId.billing)
                              _BillingPanel(
                                billing: _snapshot.billing,
                                onCatalog: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.catalog),
                                onCourses: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.home),
                              )
                            else
                              _BalancePanel(
                                balance: _snapshot.balance,
                                selectedPackageId: _selectedPackageId,
                                purchasing: _purchasing,
                                onSelectPackage: (id) =>
                                    setState(() => _selectedPackageId = id),
                                onPurchase: _purchasePack,
                              ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.selected, required this.onChanged});

  final PaymentsViewId selected;
  final ValueChanged<PaymentsViewId> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          for (final view in PaymentsViewId.values)
            Expanded(
              child: Material(
                color: selected == view ? AppColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(view),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      view.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: selected == view ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeesPanel extends StatelessWidget {
  const _FeesPanel({
    required this.fees,
    required this.paying,
    required this.receiptBusyId,
    required this.onPayNow,
    required this.onSendReceipt,
  });

  final FeesTabSnapshot fees;
  final bool paying;
  final String? receiptBusyId;
  final VoidCallback onPayNow;
  final void Function(String paymentId, List<String> channels) onSendReceipt;

  @override
  Widget build(BuildContext context) {
    if (fees.missingProfile) {
      return const _InfoCard(
        text: 'Student profile required to view institutional fees.',
      );
    }
    if (fees.settingsUnavailable) {
      return const _InfoCard(
        text: 'Fees module is unavailable for this institute.',
      );
    }
    if (!fees.moduleEnabled) {
      return const _Section(
        title: 'Fees & dues',
        subtitle: 'Institute tuition and installments.',
        child: Text(
          'Fees & payments is not turned on for this institute yet.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }

    final dues = fees.dues;
    final canPay = fees.paymentsEnabled &&
        dues.outstandingValue > 0 &&
        fees.payableAssignment != null &&
        !paying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Outstanding dues',
          subtitle: 'Tuition and institute fees assigned to you.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final card in [
                    ('Outstanding', dues.outstanding),
                    ('Total due', dues.totalDue),
                    ('Paid', dues.totalPaid),
                    ('Waived', dues.totalWaived),
                  ])
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 56) / 2,
                      child: _MetricTile(
                        label: card.$1,
                        value: '${dues.currency} ${card.$2}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: canPay ? onPayNow : null,
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                child: Text(paying ? 'Starting…' : 'Pay now'),
              ),
              if (!fees.paymentsEnabled) ...[
                const SizedBox(height: 6),
                const Text(
                  'Pay is gated until the institute enables fee payments.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Payment receipts',
          subtitle: 'Send receipts by email or WhatsApp after a fee payment.',
          child: fees.completedPayments.isEmpty
              ? const Text(
                  'No completed payments yet. After you pay, receipt actions appear here.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                )
              : Column(
                  children: [
                    for (var i = 0; i < fees.completedPayments.length; i++) ...[
                      if (i > 0) const Divider(height: 16),
                      _ReceiptRow(
                        payment: fees.completedPayments[i],
                        busy: receiptBusyId == fees.completedPayments[i].id,
                        onSend: onSendReceipt,
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Ledger',
          subtitle: 'Assignments and installment schedule.',
          child: fees.assignments.isEmpty
              ? const Text(
                  'No fee assignments yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                )
              : Column(
                  children: [
                    for (final assignment in fees.assignments) ...[
                      _AssignmentCard(assignment: assignment),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.payment,
    required this.busy,
    required this.onSend,
  });

  final FeePaymentRecord payment;
  final bool busy;
  final void Function(String paymentId, List<String> channels) onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          payment.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        Text(
          '${formatWhen(payment.paidAt)} · ${payment.id.length > 8 ? '${payment.id.substring(0, 8)}…' : payment.id}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => onSend(payment.id, const ['email']),
              child: const Text('Email'),
            ),
            OutlinedButton(
              onPressed:
                  busy ? null : () => onSend(payment.id, const ['whatsapp']),
              child: const Text('WhatsApp'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});

  final FeeAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${assignment.scheduleType} · ${assignment.status}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${assignment.currency} ${assignment.totalAmount ?? '—'} · Due ${assignment.outstandingAmount ?? '—'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (assignment.installments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final row in assignment.installments.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${row.title} · ${row.dueDate ?? '—'} · ${row.amountDue ?? '—'} · ${row.status ?? ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BillingPanel extends StatelessWidget {
  const _BillingPanel({
    required this.billing,
    required this.onCatalog,
    required this.onCourses,
  });

  final BillingTabSnapshot billing;
  final VoidCallback onCatalog;
  final VoidCallback onCourses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: onCourses,
              child: const Text('Purchased courses'),
            ),
            OutlinedButton(
              onPressed: onCatalog,
              child: const Text('Browse catalog'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Payments & invoices',
          subtitle:
              'Course enrollments, AI plan invoices, and credit pack purchases.',
          child: billing.rows.isEmpty
              ? const Text(
                  'No payments yet. Purchase a course or AI plan to see your history here.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                )
              : Column(
                  children: [
                    for (var i = 0; i < billing.rows.length; i++) ...[
                      if (i > 0) const Divider(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  billing.rows[i].title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  '${billing.rows[i].whenLabel} · ${billing.rows[i].status}'
                                  '${billing.rows[i].invoiceNumber == null ? '' : ' · ${billing.rows[i].invoiceNumber}'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            billing.rows[i].amountLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({
    required this.balance,
    required this.selectedPackageId,
    required this.purchasing,
    required this.onSelectPackage,
    required this.onPurchase,
  });

  final AiBalanceTabSnapshot balance;
  final String? selectedPackageId;
  final bool purchasing;
  final ValueChanged<String> onSelectPackage;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (balance.isEmptyWallet)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are out of AI credits',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Purchase a credit pack below to keep using AI Mentor, answer checking, and OCR.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        _Section(
          title: 'Renew AI credits',
          subtitle: 'Top up when you hit plan limits or run out of wallet credits.',
          child: balance.packages.isEmpty
              ? const Text(
                  'No credit packs are available right now.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                )
              : Column(
                  children: [
                    for (final pkg in balance.packages) ...[
                      Material(
                        color: selectedPackageId == pkg.id
                            ? AppColors.brandSoft
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelectPackage(pkg.id),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedPackageId == pkg.id
                                    ? AppColors.brand
                                    : const Color(0x14000000),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pkg.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                if (pkg.credits != null)
                                  Text(
                                    '${pkg.credits} credits',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                if (pkg.priceLabel.isNotEmpty)
                                  Text(
                                    pkg.priceLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selectedPackageId == null || purchasing
                            ? null
                            : onPurchase,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                        ),
                        child: Text(
                          purchasing
                              ? 'Purchasing…'
                              : 'Purchase selected pack',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              label: 'Total given',
              value: '${balance.given.round()}',
            ),
            _MetricTile(
              label: 'Available',
              value: '${balance.available.round()}',
              hint:
                  'AI ${balance.ai.round()} · Check ${balance.evaluation.round()} · Scan ${balance.ocr.round()}',
            ),
            _MetricTile(
              label: 'Used',
              value: '${balance.used.round()}',
            ),
          ],
        ),
        if (balance.featureBreakdown.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(
            title: 'By feature',
            subtitle: 'Credits consumed recently.',
            child: Column(
              children: [
                for (final row in balance.featureBreakdown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(row.label)),
                        Text(
                          row.credits.round().toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (balance.usage.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(
            title: 'Usage history',
            subtitle: 'Recent credit consumption.',
            child: Column(
              children: [
                for (final row in balance.usage.take(8)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              formatWhen(row.at),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text('-${row.credits.round()}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 56) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.muted)),
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
          ],
        ),
      ),
    );
  }
}
