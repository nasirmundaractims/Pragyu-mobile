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
    this.avatarMediaId,
  });

  final String id;
  final String? displayName;
  final String? phone;
  final String? locale;
  final String? timezone;
  final String? avatarUrl;
  final String? avatarMediaId;

  bool get hasAvatar {
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) return true;
    final mediaId = avatarMediaId?.trim();
    return mediaId != null && mediaId.isNotEmpty;
  }

  UserProfileSummary copyWith({
    String? displayName,
    String? phone,
    String? locale,
    String? timezone,
    String? avatarUrl,
    String? avatarMediaId,
    bool clearAvatarUrl = false,
    bool clearAvatarMediaId = false,
  }) {
    return UserProfileSummary(
      id: id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      avatarMediaId:
          clearAvatarMediaId ? null : (avatarMediaId ?? this.avatarMediaId),
    );
  }

  factory UserProfileSummary.fromJson(Map<String, dynamic> json) {
    return UserProfileSummary(
      id: json['id']?.toString() ?? '',
      displayName: _nullableTrim(json['display_name']?.toString()),
      phone: _nullableTrim(json['phone']?.toString()),
      locale: _nullableTrim(json['locale']?.toString()),
      timezone: _nullableTrim(json['timezone']?.toString()),
      avatarUrl: _nullableTrim(json['avatar_url']?.toString()),
      avatarMediaId: _nullableTrim(json['avatar_media_id']?.toString()),
    );
  }
}

class MeSnapshot {
  const MeSnapshot({
    required this.user,
    this.organizationName,
    this.organizationType,
    this.studentProfile,
    this.userProfile,
    this.emailNotificationsEnabled = true,
    this.dailyStudyHours = 2,
  });

  final AuthUser user;
  final String? organizationName;
  final String? organizationType;
  final StudentProfileSummary? studentProfile;
  final UserProfileSummary? userProfile;
  final bool emailNotificationsEnabled;
  final double dailyStudyHours;

  bool get isIndividualWorkspace => organizationType == 'individual';

  String get contextTitle {
    if (isIndividualWorkspace) return 'My Learning';
    final name = organizationName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Organisation';
  }

  String get contextSubtitle =>
      isIndividualWorkspace ? 'Individual' : 'Organisation';

  /// Whether org-only tools like Attendance belong in Me chrome.
  bool get showsOrgAttendance => !isIndividualWorkspace;

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
      organizationType: organizationType,
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
