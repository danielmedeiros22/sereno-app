import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/settings/data/local_record_deletion.dart';
import 'package:sereno_app/features/transactions/data/transaction_deletion_period.dart';

void main() {
  test('calendar filters handle day, month, year and all history', () {
    final leapDay = DateTime(2024, 2, 29);
    expect(
        TransactionDeletionPeriod(DeletionPeriodType.day, leapDay)
            .contains(DateTime(2024, 2, 29, 23, 59)),
        true);
    expect(
        TransactionDeletionPeriod(DeletionPeriodType.day, leapDay)
            .contains(DateTime(2024, 3, 1)),
        false);
    expect(
        TransactionDeletionPeriod(DeletionPeriodType.month, leapDay)
            .contains(DateTime(2024, 2, 1)),
        true);
    expect(
        TransactionDeletionPeriod(DeletionPeriodType.month, leapDay)
            .contains(DateTime(2023, 2, 28)),
        false);
    expect(
        TransactionDeletionPeriod(DeletionPeriodType.year, leapDay)
            .contains(DateTime(2024, 12, 31)),
        true);
    expect(
        TransactionDeletionPeriod(DeletionPeriodType.year, leapDay)
            .contains(DateTime(2025, 1, 1)),
        false);
    expect(
        TransactionDeletionPeriod(DeletionPeriodType.all, leapDay)
            .contains(DateTime(2000)),
        true);
  });

  for (final key in ['local_journal', 'local_recurring']) {
    test('$key batch preserves new/edited rows and unrelated settings',
        () async {
      final reviewed = [
        {'id': 'delete', 'name': 'original'},
        {'id': 'edit', 'name': 'original'},
      ];
      SharedPreferences.setMockInitialValues({
        key: jsonEncode([
          reviewed.first,
          {'id': 'edit', 'name': 'changed'},
          {'id': 'new', 'name': 'new'},
        ]),
        'theme': 'dark',
        'other_account': 'preserved',
      });
      final count = key == 'local_journal'
          ? await LocalRecordDeletion.journal(reviewed)
          : await LocalRecordDeletion.recurring(reviewed);
      expect(count, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(
          (jsonDecode(prefs.getString(key)!) as List).map((row) => row['id']),
          ['edit', 'new']);
      expect(prefs.getString('theme'), 'dark');
      expect(prefs.getString('other_account'), 'preserved');
    });
  }
}
