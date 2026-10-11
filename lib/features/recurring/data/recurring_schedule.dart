import 'recurring_model.dart';

DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);
int calendarDifference(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day)
        .difference(DateTime.utc(b.year, b.month, b.day))
        .inDays;
DateTime clampedDay(int year, int month, int day) =>
    DateTime(year, month, day.clamp(1, DateTime(year, month + 1, 0).day));
String paymentMonth(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// Legacy monthly rules are meaningful without an anchor. Other frequencies
/// need a user-confirmed first due date; do not fabricate historical dates.
List<DateTime> relevantDueDates(
    RecurringModel rule, DateTime now, int daysBefore) {
  final today = calendarDay(now);
  final horizon = DateTime(today.year, today.month, today.day + daysBefore);
  final first =
      rule.firstDueDate == null ? null : calendarDay(rule.firstDueDate!);
  if (first == null && rule.frequency != RecurringFrequency.monthly) return [];
  if (rule.frequency == RecurringFrequency.monthly) {
    return [
      for (var offset = 0; offset <= 1; offset++)
        clampedDay(today.year, today.month + offset, rule.dueDay)
    ]
        .where((date) =>
            !date.isAfter(horizon) && (first == null || !date.isBefore(first)))
        .toList();
  }
  if (rule.frequency == RecurringFrequency.yearly) {
    return [
      for (var year = today.year; year <= horizon.year; year++)
        clampedDay(year, first!.month, first.day)
    ]
        .where((date) => !date.isBefore(first!) && !date.isAfter(horizon))
        .toList();
  }
  final step = rule.frequency == RecurringFrequency.weekly ? 7 : 14;
  final delta = calendarDifference(today, first!);
  final index = delta < 0 ? 0 : delta ~/ step;
  final result = <DateTime>[];
  for (var i = index;; i++) {
    final due = DateTime(first.year, first.month, first.day + i * step);
    if (due.isAfter(horizon)) break;
    result.add(due);
  }
  return result;
}
