import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/features/catalog/data/catalog_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';

/// S-29 Catalog / browse — discover marketplace listings.
class CatalogBrowseScreen extends StatefulWidget {
  const CatalogBrowseScreen({
    super.key,
    this.catalogRepository,
  });

  final CatalogGateway? catalogRepository;

  @override
  State<CatalogBrowseScreen> createState() => _CatalogBrowseScreenState();
}

class _CatalogBrowseScreenState extends State<CatalogBrowseScreen> {
  late final CatalogGateway _catalog =
      widget.catalogRepository ?? CatalogRepository();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  CatalogSnapshot _snapshot = const CatalogSnapshot();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _catalog.loadCatalog(query: query);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load catalog. Pull to retry.';
        _loading = false;
      });
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
          title: const Text('Browse catalog'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _load(query: value),
                  decoration: InputDecoration(
                    hintText: 'Search courses',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => _load(query: _searchController.text),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.brandSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.brandSoft),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: () => _load(query: _searchController.text),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.brand)),
        ],
      );
    }

    if (_error != null && _snapshot.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      );
    }

    if (_snapshot.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'No courses found yet. Try another search, or check back soon.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: _snapshot.items.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _snapshot.items[index];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.catalogDetail,
                arguments: item.slug.isNotEmpty ? item.slug : item.id,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.brandSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (item.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Featured',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (item.metaLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.metaLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        item.priceLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const Spacer(),
                      if (item.ratingCount > 0)
                        Text(
                          '★ ${item.averageRating.toStringAsFixed(1)} (${item.ratingCount})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
