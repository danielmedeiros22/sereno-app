import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_model.dart';

class LocalTransactionService {
  static const _key = 'local_transactions';

  Future<List<TransactionModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => TransactionModel.fromJson(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> add(TransactionModel tx) async {
    final all = await getAll();
    all.insert(0, tx);
    await _save(all);
  }

  Future<void> update(TransactionModel tx) async {
    final all = await getAll();
    final idx = all.indexWhere((t) => t.id == tx.id);
    if (idx != -1) {
      all[idx] = tx;
      await _save(all);
    }
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((t) => t.id == id);
    await _save(all);
  }

  Future<void> _save(List<TransactionModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<Map<String, double>> getMonthTotals() async {
    final all = await getAll();
    final now = DateTime.now();
    final monthTxs = all.where((t) => t.date.year == now.year && t.date.month == now.month);

    double income = 0;
    double expense = 0;
    for (final tx in monthTxs) {
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }
}