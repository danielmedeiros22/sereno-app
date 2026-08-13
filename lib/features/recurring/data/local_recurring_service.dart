import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'recurring_model.dart';

class LocalRecurringService {
  static const _key = 'local_recurring';
  static const _paidKey = 'recurring_paid';

  Future<List<RecurringModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => RecurringModel.fromJson(e)).toList()
      ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
  }

  Future<void> add(RecurringModel rule) async {
    final all = await getAll();
    all.add(rule);
    await _save(all);
  }

  Future<void> update(RecurringModel rule) async {
    final all = await getAll();
    final idx = all.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      all[idx] = rule;
      await _save(all);
    }
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((r) => r.id == id);
    await _save(all);
  }

  Future<void> _save(List<RecurringModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> markPaid(String id, String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_paidKey);
    final Map<String, List<String>> paid = raw != null
        ? (jsonDecode(raw) as Map).map((k, v) => MapEntry(k, List<String>.from(v)))
        : {};
    paid.putIfAbsent(monthKey, () => []);
    if (!paid[monthKey]!.contains(id)) {
      paid[monthKey]!.add(id);
    }
    await prefs.setString(_paidKey, jsonEncode(paid));
  }

  Future<void> unmarkPaid(String id, String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_paidKey);
    if (raw == null) return;
    final Map<String, List<String>> paid =
        (jsonDecode(raw) as Map).map((k, v) => MapEntry(k, List<String>.from(v)));
    paid[monthKey]?.remove(id);
    await prefs.setString(_paidKey, jsonEncode(paid));
  }

  Future<bool> isPaid(String id, String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_paidKey);
    if (raw == null) return false;
    final Map<String, dynamic> paid = jsonDecode(raw);
    return (paid[monthKey] as List?)?.contains(id) ?? false;
  }

  Future<Set<String>> getPaidIds(String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_paidKey);
    if (raw == null) return {};
    final Map<String, dynamic> paid = jsonDecode(raw);
    return Set<String>.from(paid[monthKey] ?? []);
  }

  String currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<double> getMonthlyTotal() async {
    final all = await getAll();
    return all.where((r) => r.active).fold<double>(0.0, (sum, r) => sum + r.amount);
  }
}