enum DueUrgency {
  overdue,
  endsSoon,
  dueToday,
  dueTomorrow,
  none,
}

class DueState {
  const DueState({
    required this.urgency,
    this.label,
  });

  final DueUrgency urgency;
  final String? label;

  bool get isActionable =>
      urgency == DueUrgency.overdue ||
      urgency == DueUrgency.endsSoon ||
      urgency == DueUrgency.dueToday ||
      urgency == DueUrgency.dueTomorrow;
}

DueState deriveDueState(String? deadlineAt, {DateTime? now}) {
  if (deadlineAt == null || deadlineAt.isEmpty) {
    return const DueState(urgency: DueUrgency.none);
  }

  final due = DateTime.tryParse(deadlineAt)?.toLocal();
  if (due == null) {
    return const DueState(urgency: DueUrgency.none);
  }

  final current = (now ?? DateTime.now()).toLocal();
  final delta = due.difference(current);
  if (delta.isNegative) {
    return const DueState(urgency: DueUrgency.overdue, label: 'Overdue');
  }

  if (delta.inMinutes <= 120) {
    final mins = delta.inMinutes < 1 ? 1 : delta.inMinutes;
    final hours = mins ~/ 60;
    final rem = mins % 60;
    final label = hours > 0
        ? (rem > 0 ? 'Ends in ${hours}h ${rem}m' : 'Ends in $hours h')
        : 'Ends in $mins min';
    return DueState(urgency: DueUrgency.endsSoon, label: label);
  }

  final startOfToday = DateTime(current.year, current.month, current.day);
  final startOfTomorrow = startOfToday.add(const Duration(days: 1));
  final startOfDayAfter = startOfToday.add(const Duration(days: 2));

  if (!due.isBefore(startOfToday) && due.isBefore(startOfTomorrow)) {
    return const DueState(urgency: DueUrgency.dueToday, label: 'Due today');
  }
  if (!due.isBefore(startOfTomorrow) && due.isBefore(startOfDayAfter)) {
    return const DueState(
      urgency: DueUrgency.dueTomorrow,
      label: 'Due tomorrow',
    );
  }

  return const DueState(urgency: DueUrgency.none);
}
