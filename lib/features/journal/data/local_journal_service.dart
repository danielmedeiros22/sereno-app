import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'journal_model.dart';

class LocalJournalService {
  static const _key = 'local_journal';

  Future<List<JournalEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => JournalEntry.fromJson(e)).toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }

  Future<void> add(JournalEntry entry) async {
    final all = await getAll();
    all.insert(0, entry);
    await _save(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((e) => e.id == id);
    await _save(all);
  }

  Future<void> _save(List<JournalEntry> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}