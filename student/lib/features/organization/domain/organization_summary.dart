class OrganizationSummary {
  const OrganizationSummary({
    required this.id,
    required this.name,
    this.type,
    this.status,
    this.slug,
  });

  final String id;
  final String name;
  final String? type;
  final String? status;
  final String? slug;

  factory OrganizationSummary.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['organization_id'])?.toString() ?? '';
    return OrganizationSummary(
      id: id,
      name: json['name']?.toString() ?? 'Organization',
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      slug: json['slug']?.toString(),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'institute':
        return 'Institute';
      case 'individual':
        return 'Individual';
      default:
        return type ?? 'Workspace';
    }
  }
}
