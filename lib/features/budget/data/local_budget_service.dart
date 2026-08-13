import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'budget_model.dart';

class LocalBudgetService {
  static const _key = 'local_budgets';

  Future<List<BudgetModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => BudgetModel.fromJson(e)).toList()
      ..sort((a, b) => a.category.compareTo(b.category));
  }

  Future<void> add(BudgetModel budget) async {
    final all = await getAll();
    all.removeWhere((b) => b.category == budget.category);
    all.add(budget);
    await _save(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((b) => b.id == id);
    await _save(all);
  }

  Future<void> _save(List<BudgetModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}