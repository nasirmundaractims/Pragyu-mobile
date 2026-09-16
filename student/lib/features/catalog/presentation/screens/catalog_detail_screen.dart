import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/catalog/data/catalog_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_checkout_models.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';

/// S-29 Catalog detail — listing summary with S-73 Buy / Enroll checkout.
class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen({
    super.key,
    required this.slug,
    this.catalogRepository,
  });

  final String slug;
  final CatalogGateway? catalogRepository;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  late final CatalogGateway _catalog =
      widget.catalogRepository ?? CatalogRepository();

  final _couponController = TextEditingController();

  bool _loading = true;
  String? _error;
  CatalogListing? _listing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listing = await _catalog.loadListing(widget.slug);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to open this listing.';
        _loading = false;
      });
    }
  }

  void _startCheckout() {
    final listing = _listing;
    if (listing == null || !listing.canCheckout) return;
    Navigator.of(context).pushNamed(
      AppRoutes.catalogCheckout,
      arguments: CatalogCheckoutArgs(
        programId: listing.programId,
        courseId: listing.courseId,
        title: listing.title,
        couponCode: _couponController.text.trim().isEmpty
            ? null
            : _couponController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _listing?.title ?? 'Course';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _listing == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.brand)),
        ],
      );
    }

    if (_error != null && _listing == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      );
    }

    final listing = _listing!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          listing.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        if (listing.subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            listing.subtitle!,
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          listing.priceLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
        if (listing.sellerName != null) ...[
          const SizedBox(height: 8),
          Text(
            'By ${listing.sellerName}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
        if (listing.shortDescription?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          Text(
            listing.shortDescription!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.ink,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (listing.canCheckout) ...[
          TextField(
            controller: _couponController,
            decoration: InputDecoration(
              labelText: 'Coupon code (optional)',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _startCheckout,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Buy / Enroll'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You are enrolled only after payment succeeds. Razorpay may open in the browser when needed.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'This listing is not linked to a purchasable course offer yet. '
              'Browse other catalog items, or ask your academy to publish a commerce course.',
              style: TextStyle(height: 1.45, color: AppColors.ink),
            ),
          ),
      ],
    );
  }
}
