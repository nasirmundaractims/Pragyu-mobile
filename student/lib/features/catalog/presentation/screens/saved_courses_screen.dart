import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/catalog/data/wishlist_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';
import 'package:student_mobile/features/catalog/domain/wishlist_models.dart';

/// Slice 5.2 — Saved courses (marketplace wishlist).
class SavedCoursesScreen extends StatefulWidget {
  const SavedCoursesScreen({
    super.key,
    this.wishlistRepository,
  });

  final WishlistGateway? wishlistRepository;

  @override
  State<SavedCoursesScreen> createState() => _SavedCoursesScreenState();
}

class _SavedCoursesScreenState extends State<SavedCoursesScreen> {
  late final WishlistGateway _wishlist =
      widget.wishlistRepository ?? WishlistRepository();

  bool _loading = true;
  String? _error;
  WishlistSnapshot _snapshot = const WishlistSnapshot();
  final Set<String> _removing = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _wishlist.loadWishlist();
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
            : 'Unable to load saved courses.';
      });
    }
  }

  Future<void> _remove(CatalogListing listing) async {
    if (_removing.contains(listing.id)) return;
    final previous = _snapshot;
    setState(() {
      _removing.add(listing.id);
      _snapshot = _snapshot.withoutListing(listing.id);
    });
    try {
      await _wishlist.removeListing(listing.id);
      if (!mounted) return;
      setState(() => _removing.remove(listing.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from saved courses.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = previous;
        _removing.remove(listing.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : "Couldn't remove this listing.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openListing(CatalogListing listing) {
    final slug = listing.slug.isNotEmpty ? listing.slug : listing.id;
    if (slug.isEmpty) return;
    Navigator.of(context).pushNamed(AppRoutes.catalogDetail, arguments: slug);
  }

  void _browseCatalog() {
    Navigator.of(context).pushNamed(AppRoutes.catalog);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Saved courses',
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot.isEmpty) {
      return const AppLoadingState(padding: EdgeInsets.zero);
    }

    if (_error != null && _snapshot.isEmpty) {
      return Center(
        child: AppErrorState(
          message: _error!,
          onRetry: _load,
          retryLabel: 'Retry',
        ),
      );
    }

    return RefreshIndicator(
      color: StudentHubColors.blue,
      onRefresh: _load,
      child: _snapshot.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
              children: [
                AppEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No saved courses yet',
                  message:
                      'Tap Save on a catalog listing to keep it here until you are ready to buy.',
                  actionLabel: 'Browse catalog',
                  onAction: _browseCatalog,
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: StudentHubColors.danger),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  '${_snapshot.count} saved · open a listing to buy or unsave',
                  style: const TextStyle(
                    color: StudentHubColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                for (final item in _snapshot.items) ...[
                  _SavedCourseTile(
                    listing: item,
                    removing: _removing.contains(item.id),
                    onOpen: () => _openListing(item),
                    onRemove: () => _remove(item),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _SavedCourseTile extends StatelessWidget {
  const _SavedCourseTile({
    required this.listing,
    required this.removing,
    required this.onOpen,
    required this.onRemove,
  });

  final CatalogListing listing;
  final bool removing;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        onTap: onOpen,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
            border: Border.all(color: StudentHubColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: StudentHubColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  listing.isTestSeriesListing
                      ? Icons.quiz_outlined
                      : Icons.menu_book_rounded,
                  color: StudentHubColors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: StudentHubColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.priceLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: StudentHubColors.blue,
                      ),
                    ),
                    if (listing.sellerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'By ${listing.sellerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: StudentHubColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: removing ? null : onRemove,
                icon: removing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: StudentHubColors.blue,
                        ),
                      )
                    : const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFE85D75),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
