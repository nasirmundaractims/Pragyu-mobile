import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';

abstract class CatalogGateway {
  Future<CatalogSnapshot> loadCatalog({String? query});
  Future<CatalogListing> loadListing(String slug);
}

class CatalogRepository implements CatalogGateway {
  CatalogRepository({
    http.Client? httpClient,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.instance.apiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  @override
  Future<CatalogSnapshot> loadCatalog({String? query}) async {
    final q = query?.trim() ?? '';
    final uri = Uri.parse(_join(_baseUrl, '/public/marketplace/catalog')).replace(
      queryParameters: {
        'limit': '50',
        'offset': '0',
        if (q.isNotEmpty) 'q': q,
      },
    );
    final response = await _http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    final decoded = _decode(response);
    final data = decoded['data'];
    if (data is! List) {
      return CatalogSnapshot(query: q);
    }
    final items = data
        .whereType<Map>()
        .map(
          (item) => CatalogListing.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .where((item) => item.slug.isNotEmpty || item.id.isNotEmpty)
        .toList(growable: false);
    return CatalogSnapshot(items: items, query: q);
  }

  @override
  Future<CatalogListing> loadListing(String slug) async {
    final clean = slug.trim();
    if (clean.isEmpty) {
      throw ArgumentError('slug is required');
    }
    final uri = Uri.parse(
      _join(_baseUrl, '/public/marketplace/catalog/$clean'),
    );
    final response = await _http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    final decoded = _decode(response);
    final data = decoded['data'] ?? decoded;
    if (data is! Map) {
      throw StateError('Listing not found');
    }
    return CatalogListing.fromJson(
      data.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Catalog request failed (${response.statusCode})');
    }
    if (response.body.isEmpty) return const {};
    final raw = jsonDecode(response.body);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  static String _join(String base, String path) {
    final normalizedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }
}
