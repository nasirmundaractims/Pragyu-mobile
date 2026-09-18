import 'package:student_mobile/features/auth/domain/auth_models.dart';

// S-70 Me — profile + settings snapshot models.

class StudentProfileSummary {
  const StudentProfileSummary({
    required this.id,
    this.studentCode,
    this.status,
  });

  final String id;
  final String? studentCode;
  final String? status;

  factory StudentProfileSummary.fromJson(Map<String, dynamic> json) {
    return StudentProfileSummary(
      id: json['id']?.toString() ?? '',
      studentCode: _nullableTrim(json['student_code']?.toString()),
      status: _nullableTrim(json['status']?.toString()),
    );
  }
}

class UserProfileSummary {
  const UserProfileSummary({
    required this.id,
    this.displayName,
    this.phone,
    this.locale,
    this.timezone,
    this.avatarUrl,
  });

  final String id;
  final String? displayName;
  final String? phone;
  final String? locale;
  final String? timezone;
  final String? avatarUrl;

  factory UserProfileSummary.fromJson(Map<String, dynamic> json) {
    return UserProfileSummary(
      id: json['id']?.toString() ?? '',
      displayName: _nullableTrim(json['display_name']?.toString()),
      phone: _nullableTrim(json['phone']?.toString()),
      locale: _nullableTrim(json['locale']?.toString()),
      timezone: _nullableTrim(json['timezone']?.toString()),
      avatarUrl: _nullableTrim(json['avatar_url']?.toString()),
    );
  }
}

class MeSnapshot {
  const MeSnapshot({
    required this.user,
    this.organizationName,
    this.studentProfile,
    this.userProfile,
    this.emailNotificationsEnabled = true,
    this.dailyStudyHours = 2,
  });

  final AuthUser user;
  final String? organizationName;
  final StudentProfileSummary? studentProfile;
  final UserProfileSummary? userProfile;
  final bool emailNotificationsEnabled;
  final double dailyStudyHours;

  String get displayName {
    final fromProfile = userProfile?.displayName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return user.displayName;
  }

  MeSnapshot copyWith({
    bool? emailNotificationsEnabled,
    double? dailyStudyHours,
    UserProfileSummary? userProfile,
  }) {
    return MeSnapshot(
      user: user,
      organizationName: organizationName,
      studentProfile: studentProfile,
      userProfile: userProfile ?? this.userProfile,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      dailyStudyHours: dailyStudyHours ?? this.dailyStudyHours,
    );
  }
}

String? _nullableTrim(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
