/// S-30 Calendar — upcoming live classes and test deadlines.
enum CalendarEventKind { live, test }

enum CalendarFilter { all, live, tests }

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.startsAt,
    required this.sourceId,
    this.subtitle,
    this.isLiveNow = false,
  });

  final String id;
  final CalendarEventKind kind;
  final String title;
  final DateTime startsAt;
  final String sourceId;
  final String? subtitle;
  final bool isLiveNow;

  String get kindLabel {
    switch (kind) {
      case CalendarEventKind.live:
        return isLiveNow ? 'Live now' : 'Live class';
      case CalendarEventKind.test:
        return 'Test deadline';
    }
  }

  /// Live → S-24; tests → S-41 when that screen ships.
  String get nextScreenId {
    switch (kind) {
      case CalendarEventKind.live:
        return 'S-24';
      case CalendarEventKind.test:
        return 'S-41';
    }
  }
}

class CalendarDayGroup {
  const CalendarDayGroup({
    required this.day,
    this.events = const [],
  });

  final DateTime day;
  final List<CalendarEvent> events;

  bool get isEmpty => events.isEmpty;
}

class CalendarSnapshot {
  const CalendarSnapshot({
    this.days = const [],
    this.horizonDays = 14,
  });

  final List<CalendarDayGroup> days;
  final int horizonDays;

  bool get isEmpty => days.every((day) => day.isEmpty);

  List<CalendarEvent> get allEvents =>
      days.expand((day) => day.events).toList(growable: false);

  CalendarSnapshot filtered(CalendarFilter filter) {
    if (filter == CalendarFilter.all) return this;
    final kind = filter == CalendarFilter.live
        ? CalendarEventKind.live
        : CalendarEventKind.test;
    final filteredDays = <CalendarDayGroup>[];
    for (final day in days) {
      final events =
          day.events.where((e) => e.kind == kind).toList(growable: false);
      if (events.isEmpty) continue;
      filteredDays.add(CalendarDayGroup(day: day.day, events: events));
    }
    return CalendarSnapshot(days: filteredDays, horizonDays: horizonDays);
  }

  static CalendarSnapshot fromEvents(
    List<CalendarEvent> events, {
    int horizonDays = 14,
  }) {
    final sorted = [...events]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final groups = <String, List<CalendarEvent>>{};
    final dayKeys = <String, DateTime>{};

    for (final event in sorted) {
      final local = event.startsAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final key = '${day.year}-${day.month}-${day.day}';
      dayKeys.putIfAbsent(key, () => day);
      groups.putIfAbsent(key, () => <CalendarEvent>[]).add(event);
    }

    final days = dayKeys.entries
        .map(
          (entry) => CalendarDayGroup(
            day: entry.value,
            events: groups[entry.key] ?? const [],
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.day.compareTo(b.day));

    return CalendarSnapshot(days: days, horizonDays: horizonDays);
  }
}

bool isWithinCalendarHorizon(
  DateTime when, {
  required DateTime start,
  required DateTime end,
}) {
  final t = when.toLocal();
  return !t.isBefore(start) && !t.isAfter(end);
}

DateTime calendarHorizonStart(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime calendarHorizonEnd(DateTime now, {int horizonDays = 14}) {
  final start = calendarHorizonStart(now);
  return start
      .add(Duration(days: horizonDays))
      .add(const Duration(hours: 23, minutes: 59, seconds: 59));
}

/// Prefer deadline, then closes, then scheduled (matches student-web calendar).
DateTime? assessmentWhen(Map<String, dynamic> json) {
  for (final key in ['deadline_at', 'closes_at', 'scheduled_at']) {
    final raw = json[key]?.toString();
    if (raw == null || raw.isEmpty) continue;
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed != null) return parsed;
  }
  return null;
}

String assessmentWhenLabel(Map<String, dynamic> json) {
  if (json['deadline_at'] != null &&
      json['deadline_at'].toString().trim().isNotEmpty) {
    return 'Due';
  }
  if (json['closes_at'] != null &&
      json['closes_at'].toString().trim().isNotEmpty) {
    return 'Closes';
  }
  if (json['scheduled_at'] != null &&
      json['scheduled_at'].toString().trim().isNotEmpty) {
    return 'Scheduled';
  }
  return 'Test';
}
