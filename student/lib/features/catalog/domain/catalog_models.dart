class CatalogListing {
  const CatalogListing({
    required this.id,
    required this.slug,
    required this.title,
    this.subtitle,
    this.shortDescription,
    this.thumbnailUrl,
    this.listingType,
    this.category,
    this.level,
    this.format,
    this.price,
    this.discountPrice,
    this.currency,
    this.isFeatured = false,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.sellerName,
    this.programId,
    this.courseId,
  });

  final String id;
  final String slug;
  final String title;
  final String? subtitle;
  final String? shortDescription;
  final String? thumbnailUrl;
  final String? listingType;
  final String? category;
  final String? level;
  final String? format;
  final num? price;
  final num? discountPrice;
  final String? currency;
  final bool isFeatured;
  final double averageRating;
  final int ratingCount;
  final String? sellerName;
  final String? programId;
  final String? courseId;

  bool get canCheckout =>
      (programId?.trim().isNotEmpty == true) &&
      (courseId?.trim().isNotEmpty == true);

  String get priceLabel {
    if (price == null) return 'Free / Contact';
    final amount = discountPrice ?? price;
    return _formatMoney(amount, currency);
  }

  /// Current / sale price for marketplace cards.
  String get salePriceLabel {
    if (price == null && discountPrice == null) return 'Free / Contact';
    return _formatMoney(discountPrice ?? price, currency);
  }

  /// Original list price when a discount applies; otherwise null.
  String? get listPriceLabel {
    if (price == null || discountPrice == null) return null;
    if (discountPrice! >= price!) return null;
    return _formatMoney(price, currency);
  }

  bool get isTestSeriesListing {
    final type = (listingType ?? '').toLowerCase();
    return type.contains('test') || type.contains('exam');
  }

  bool get isCourseListing {
    final type = (listingType ?? '').toLowerCase();
    if (type.isEmpty) return true;
    if (isTestSeriesListing) return false;
    return type.contains('course') ||
        type.contains('program') ||
        type.contains('live') ||
        type.contains('material');
  }

  String get metaLabel {
    final parts = <String>[
      if (category != null && category!.isNotEmpty) category!,
      if (level != null && level!.isNotEmpty) level!,
      if (format != null && format!.isNotEmpty) format!,
    ];
    return parts.join(' · ');
  }

  static String _formatMoney(num? amount, String? currency) {
    if (amount == null) return 'Free';
    final code = (currency ?? 'INR').toUpperCase();
    final formatted = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    if (code == 'INR') return '₹$formatted';
    return '$code $formatted';
  }

  factory CatalogListing.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'];
    String? sellerName;
    if (seller is Map) {
      sellerName = seller['display_name']?.toString() ??
          seller['name']?.toString() ??
          seller['slug']?.toString();
    }
    return CatalogListing(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Course',
      subtitle: json['subtitle']?.toString(),
      shortDescription: json['short_description']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      listingType: json['listing_type']?.toString(),
      category: json['category']?.toString(),
      level: json['level']?.toString(),
      format: json['format']?.toString(),
      price: json['price'] is num
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? ''),
      discountPrice: json['discount_price'] is num
          ? json['discount_price'] as num
          : num.tryParse(json['discount_price']?.toString() ?? ''),
      currency: json['currency']?.toString(),
      isFeatured: json['is_featured'] == true,
      averageRating: (json['average_rating'] is num)
          ? (json['average_rating'] as num).toDouble()
          : double.tryParse(json['average_rating']?.toString() ?? '') ?? 0,
      ratingCount: int.tryParse(json['rating_count']?.toString() ?? '') ?? 0,
      sellerName: sellerName,
      programId: json['program_id']?.toString() ??
          json['programId']?.toString(),
      courseId: json['course_id']?.toString() ??
          json['courseId']?.toString(),
    );
  }
}

class CatalogSnapshot {
  const CatalogSnapshot({this.items = const [], this.query = ''});

  final List<CatalogListing> items;
  final String query;

  bool get isEmpty => items.isEmpty;
}
