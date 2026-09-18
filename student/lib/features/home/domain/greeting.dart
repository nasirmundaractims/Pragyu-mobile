String localGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String firstNameFrom(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return 'Student';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Prefer profile display name, then identity first name, then fallback.
String greetingFirstName({
  String? firstName,
  String? profileDisplayName,
  String? fallbackDisplayName,
}) {
  final fromProfile = profileDisplayName?.trim();
  if (fromProfile != null && fromProfile.isNotEmpty) {
    return firstNameFrom(fromProfile);
  }
  final fromIdentity = firstName?.trim();
  if (fromIdentity != null && fromIdentity.isNotEmpty) {
    return fromIdentity.split(RegExp(r'\s+')).first;
  }
  final fallback = fallbackDisplayName?.trim();
  if (fallback != null && fallback.isNotEmpty) {
    return firstNameFrom(fallback);
  }
  return 'Student';
}

/// First letter of first name + first letter of last name.
String initialsFromNames({
  String? firstName,
  String? lastName,
  String? profileDisplayName,
  String? fallbackDisplayName,
}) {
  final first = firstName?.trim() ?? '';
  final last = lastName?.trim() ?? '';
  if (first.isNotEmpty && last.isNotEmpty) {
    return '${first[0]}${last[0]}'.toUpperCase();
  }
  if (first.isNotEmpty) {
    return first.length >= 2
        ? first.substring(0, 2).toUpperCase()
        : first[0].toUpperCase();
  }

  final source = (profileDisplayName ?? fallbackDisplayName)?.trim() ?? '';
  final parts = source
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  if (parts.length == 1) {
    final part = parts.first;
    return part.length >= 2
        ? part.substring(0, 2).toUpperCase()
        : part[0].toUpperCase();
  }
  return 'ST';
}
