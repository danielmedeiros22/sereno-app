enum DeletionPeriodType { day, month, year, all }

/// Calendar boundaries use the transaction date, not its creation timestamp.
class TransactionDeletionPeriod {
  const TransactionDeletionPeriod(this.type, this.date);

  final DeletionPeriodType type;
  final DateTime date;

  bool contains(DateTime value) {
    return switch (type) {
      DeletionPeriodType.day => value.year == date.year &&
          value.month == date.month &&
          value.day == date.day,
      DeletionPeriodType.month =>
        value.year == date.year && value.month == date.month,
      DeletionPeriodType.year => value.year == date.year,
      DeletionPeriodType.all => true,
    };
  }
}
