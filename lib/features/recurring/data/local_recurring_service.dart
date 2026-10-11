import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/account_record_store.dart';
import 'recurring_model.dart';

class LocalRecurringService {
  LocalRecurringService({String? owner, AccountRecordRemote? remote})
      : store = AccountRecordStore(
            kind: 'recurring',
            guestKey: 'local_recurring',
            owner: owner,
            remote: remote),
        payments = AccountRecordStore(
            kind: 'paid',
            guestKey: 'recurring_paid_records',
            owner: owner,
            remote: remote);
  final AccountRecordStore store;
  final AccountRecordStore payments;
  Future<List<RecurringModel>> getAll() async =>
      (await store.getAll()).map(RecurringModel.fromJson).toList()
        ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
  Future<void> add(RecurringModel rule) => store.save(rule.toJson());
  Future<void> update(RecurringModel rule) => store.save(rule.toJson());
  Future<void> delete(String id) async {
    await store.delete(id);
    await _deletePayments({id});
  }

  Future<int> deleteReviewed(List<RecurringModel> rows) async {
    final count =
        await store.deleteReviewed(rows.map((r) => r.toJson()).toList());
    final remaining = (await getAll()).map((r) => r.id).toSet();
    await _deletePayments(
        rows.map((r) => r.id).where((id) => !remaining.contains(id)).toSet());
    return count;
  }

  Future<void> _deletePayments(Set<String> ids) async {
    final rows = (await payments.getAll())
        .where((row) => ids.contains(row['rule_id']))
        .toList();
    await payments.deleteReviewed(rows);
    // Historical guest payment flags are ignored when their rule is gone.
  }

  Future<void> synchronize() async {
    await store.synchronize();
    await payments.synchronize();
  }

  Future<void> markPaid(String id, String monthKey) async {
    await payments.save({
      'id': '$id:$monthKey',
      'rule_id': id,
      'month': monthKey,
      'paid': true
    });
  }

  Future<void> unmarkPaid(String id, String monthKey) async {
    // A false value overrides a historical guest payment too.
    await payments.save({
      'id': '$id:$monthKey',
      'rule_id': id,
      'month': monthKey,
      'paid': false
    });
  }

  Future<bool> isPaid(String id, String monthKey) async =>
      (await getPaidIds(monthKey)).contains(id);
  Future<Set<String>> getPaidIds(String monthKey) async {
    final result = <String>{};
    if (store.owner == null) {
      final raw =
          (await SharedPreferences.getInstance()).getString('recurring_paid');
      if (raw != null) {
        result.addAll(
            List<String>.from((jsonDecode(raw) as Map)[monthKey] ?? []));
      }
    }
    for (final row in await payments.getAll()) {
      if (row['month'] == monthKey) {
        if (row['paid'] == true) {
          result.add(row['rule_id'] as String);
        } else {
          result.remove(row['rule_id']);
        }
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> legacyPayments() async {
    final raw =
        (await SharedPreferences.getInstance()).getString('recurring_paid');
    final result = <String, Map<String, dynamic>>{};
    if (raw != null) {
      for (final month in (jsonDecode(raw) as Map).entries) {
        for (final id in month.value as List) {
          result['$id:${month.key}'] = {
            'id': '$id:${month.key}',
            'rule_id': id,
            'month': month.key,
            'paid': true
          };
        }
      }
    }
    for (final row in await LocalRecurringService().payments.getAll()) {
      result[row['id'] as String] = row;
    }
    return result.values.toList();
  }

  String currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<double> getMonthlyTotal() async => (await getAll())
      .where((r) => r.active)
      .fold<double>(0, (sum, r) => sum + r.amount);
}
