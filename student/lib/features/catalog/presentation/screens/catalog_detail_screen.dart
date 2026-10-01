import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/student_hub_colors.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/catalog/data/catalog_repository.dart';
import 'package:student_mobile/features/catalog/data/wishlist_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_checkout_models.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';

/// S-29 Catalog detail — listing summary with S-73 Buy / Enroll checkout.
/// Slice 5.2 — save / unsave via marketplace wishlist.
class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen({
    super.key,
    required this.slug,
    this.catalogRepository,
    this.wishlistRepository,
  });

  final String slug;
  final CatalogGateway? catalogRepository;
  final WishlistGateway? wishlistRepository;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  late final CatalogGateway _catalog =
      widget.catalogRepository ?? CatalogRepository();
  late final WishlistGateway _wishlist =
      widget.wishlistRepository ?? WishlistRepository();

  final _couponController = TextEditingController();

  bool _loading = true;
  bool _wishlistLoading = false;
  bool _savingWishlist = false;
  bool _saved = false;
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
      await _refreshSavedState(listing.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to open this listing.';
        _loading = false;
      });
    }
  }

  Future<void> _refreshSavedState(String listingId) async {
    if (listingId.trim().isEmpty) return;
    setState(() => _wishlistLoading = true);
    try {
      final saved = await _wishlist.isSaved(listingId);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _wishlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _wishlistLoading = false);
    }
  }

  Future<void> _toggleSave() async {
    final listing = _listing;
    if (listing == null || listing.id.isEmpty || _savingWishlist) return;

    final wasSaved = _saved;
    setState(() {
      _savingWishlist = true;
      _saved = !wasSaved;
    });

    try {
      if (wasSaved) {
        await _wishlist.removeListing(listing.id);
      } else {
        await _wishlist.saveListing(listing.id);
      }
      if (!mounted) return;
      setState(() => _savingWishlist = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved ? 'Removed from saved courses.' : 'Saved for later.',
          ),
          behavior: SnackBarBehavior.floating,
          action: wasSaved
              ? null
              : SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.savedCourses);
                  },
                ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saved = wasSaved;
        _savingWishlist = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : "Couldn't update saved courses.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        backgroundColor: StudentHubColors.pageBg,
        appBar: AppBar(
          backgroundColor: StudentHubColors.pageBg,
          title: Text(title),
          actions: [
            if (_listing != null)
              IconButton(
                tooltip: _saved ? 'Remove from saved' : 'Save for later',
                onPressed: _savingWishlist || _wishlistLoading
                    ? null
                    : _toggleSave,
                icon: _savingWishlist || _wishlistLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: StudentHubColors.blue,
                        ),
                      )
                    : Icon(
                        _saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _saved
                            ? const Color(0xFFE85D75)
                            : StudentHubColors.ink,
                      ),
              ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: StudentHubColors.blue,
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
          Center(child: CircularProgressIndicator(color: StudentHubColors.blue)),
        ],
      );
    }

    if (_error != null && _listing == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: const TextStyle(color: StudentHubColors.danger)),
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
            color: StudentHubColors.ink,
          ),
        ),
        if (listing.subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            listing.subtitle!,
            style: const TextStyle(fontSize: 15, color: StudentHubColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          listing.priceLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: StudentHubColors.blue,
          ),
        ),
        if (listing.sellerName != null) ...[
          const SizedBox(height: 8),
          Text(
            'By ${listing.sellerName}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: StudentHubColors.muted,
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
              color: StudentHubColors.ink,
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
              fillColor: StudentHubColors.surface,
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
              style: FilledButton.styleFrom(
                backgroundColor: StudentHubColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Buy / Enroll'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _savingWishlist || _wishlistLoading ? null : _toggleSave,
            icon: Icon(
              _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _saved ? const Color(0xFFE85D75) : StudentHubColors.blue,
            ),
            label: Text(_saved ? 'Saved' : 'Save for later'),
            style: OutlinedButton.styleFrom(
              foregroundColor: StudentHubColors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: StudentHubColors.blue, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You are enrolled only after payment succeeds. Razorpay may open in the browser when needed.',
            style: TextStyle(fontSize: 12, color: StudentHubColors.muted, height: 1.4),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: _savingWishlist || _wishlistLoading ? null : _toggleSave,
            icon: Icon(
              _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _saved ? const Color(0xFFE85D75) : StudentHubColors.blue,
            ),
            label: Text(_saved ? 'Saved' : 'Save for later'),
            style: OutlinedButton.styleFrom(
              foregroundColor: StudentHubColors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: StudentHubColors.blue, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StudentHubColors.blueSoft,
              borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
              border: Border.all(color: StudentHubColors.border),
            ),
            child: const Text(
              'This listing is not linked to a purchasable course offer yet. '
              'Browse other catalog items, or ask your academy to publish a commerce course.',
              style: TextStyle(height: 1.45, color: StudentHubColors.ink),
            ),
          ),
        ],
      ],
    );
  }
}
