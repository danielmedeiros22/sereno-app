import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../transactions/data/default_categories.dart';
import '../transactions/data/transaction_model.dart';
import '../transactions/presentation/providers/summary_period.dart';
import '../transactions/presentation/providers/transaction_provider.dart';

final reportProvider = Provider<AsyncValue<ReportData>>((ref) {
  final period = ref.watch(summaryPeriodProvider);
  final space = ref.watch(selectedSpaceProvider);
  return ref.watch(transactionListProvider).whenData((records) =>
      ReportData.fromRecords(
          records.where((tx) => space == null || tx.spaceId == space).toList(),
          period));
});

class CategoryTotal {
  CategoryTotal(this.name, this.icon);
  final String name;
  final String icon;
  int cents = 0;
}

class ReportData {
  ReportData(this.period, this.income, this.expense, this.count,
      this.categories, this.buckets);
  final SummaryPeriod period;
  final int income;
  final int expense;
  final int count;
  final List<CategoryTotal> categories;
  final List<int> buckets;

  factory ReportData.fromRecords(
      List<TransactionModel> records, SummaryPeriod period) {
    final hourly = period.type == SummaryPeriodType.day;
    final length = hourly
        ? 24
        : DateTime.utc(period.endExclusive.year, period.endExclusive.month,
                period.endExclusive.day)
            .difference(DateTime.utc(
                period.start.year, period.start.month, period.start.day))
            .inDays;
    // Calendar indices, rather than elapsed local hours, also work across DST.
    final buckets = List.filled(length, 0);
    final groups = <String, CategoryTotal>{};
    var income = 0, expense = 0, count = 0;
    for (final tx in records.where((tx) => period.contains(tx.date))) {
      if (!tx.isIncome && !tx.isExpense) continue;
      final cents = (tx.amount * 100).round();
      count++;
      if (tx.isIncome) {
        income += cents;
      } else {
        expense += cents;
        final key = categoryNameKey(tx.category);
        final category = groups.putIfAbsent(key,
            () => CategoryTotal(tx.category.trim(), tx.categoryIcon ?? '📦'));
        category.cents += cents;
        final date = tx.date.toLocal();
        final index = hourly
            ? date.hour
            : DateTime.utc(date.year, date.month, date.day)
                .difference(DateTime.utc(
                    period.start.year, period.start.month, period.start.day))
                .inDays;
        buckets[index] += cents;
      }
    }
    final categories = groups.values.toList()
      ..sort((a, b) {
        final amount = b.cents.compareTo(a.cents);
        return amount == 0 ? a.name.compareTo(b.name) : amount;
      });
    return ReportData(period, income, expense, count, categories, buckets);
  }
}
