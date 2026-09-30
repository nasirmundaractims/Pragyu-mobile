import 'package:student_mobile/features/organization/domain/organization_summary.dart';

class OrganizationMembershipPreview {
  const OrganizationMembershipPreview({
    required this.organizationId,
    required this.organizationName,
    this.organizationType,
    this.role,
    this.expiresAt,
    this.status,
  });

  final String organizationId;
  final String organizationName;
  final String? organizationType;
  final String? role;
  final String? expiresAt;
  final String? status;

  factory OrganizationMembershipPreview.fromJson(Map<String, dynamic> json) {
    return OrganizationMembershipPreview(
      organizationId: json['organization_id']?.toString() ?? '',
      organizationName: json['organization_name']?.toString() ?? 'Organisation',
      organizationType: json['organization_type']?.toString(),
      role: json['role']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class OrganizationMembershipRedeemResult {
  const OrganizationMembershipRedeemResult({
    required this.status,
    required this.message,
    required this.organizationId,
    required this.organizationName,
    this.organizationType,
    this.memberId,
    this.roleName,
  });

  final String status;
  final String message;
  final String organizationId;
  final String organizationName;
  final String? organizationType;
  final String? memberId;
  final String? roleName;

  factory OrganizationMembershipRedeemResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrganizationMembershipRedeemResult(
      status: json['status']?.toString() ?? 'joined',
      message:
          json['message']?.toString() ?? 'You have joined the organisation.',
      organizationId: json['organization_id']?.toString() ?? '',
      organizationName: json['organization_name']?.toString() ?? 'Organisation',
      organizationType: json['organization_type']?.toString(),
      memberId: json['member_id']?.toString(),
      roleName: json['role_name']?.toString(),
    );
  }

  OrganizationSummary toOrganizationSummary() {
    return OrganizationSummary(
      id: organizationId,
      name: organizationName,
      type: organizationType ?? 'institute',
      status: 'active',
    );
  }
}
