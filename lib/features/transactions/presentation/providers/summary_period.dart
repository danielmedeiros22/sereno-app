import 'package:intl/intl.dart';

enum SummaryPeriodType { day, week, month }

class SummaryPeriod {
  SummaryPeriod(this.type, DateTime reference)
      : date = DateTime(reference.year, reference.month, reference.day);

  final SummaryPeriodType type;
  final DateTime date;

  DateTime get start => switch (type) {
        SummaryPeriodType.day => date,
        SummaryPeriodType.week =>
          DateTime(date.year, date.month, date.day - date.weekday + 1),
        SummaryPeriodType.month => DateTime(date.year, date.month),
      };

  DateTime get endExclusive => switch (type) {
        SummaryPeriodType.day => DateTime(date.year, date.month, date.day + 1),
        SummaryPeriodType.week =>
          DateTime(start.year, start.month, start.day + 7),
        SummaryPeriodType.month => DateTime(date.year, date.month + 1),
      };

  bool contains(DateTime value) {
    final local = value.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  String get label => switch (type) {
        SummaryPeriodType.day => DateFormat.yMMMMd('pt_BR').format(date),
        SummaryPeriodType.week =>
          '${DateFormat('dd/MM/yyyy').format(start)} – ${DateFormat('dd/MM/yyyy').format(DateTime(start.year, start.month, start.day + 6))}',
        SummaryPeriodType.month => DateFormat.yMMMM('pt_BR').format(date),
      };
}
