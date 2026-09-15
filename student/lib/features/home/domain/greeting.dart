String localGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String firstNameFrom(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return 'Student';
  return trimmed.split(RegExp(r'\s+')).first;
}
