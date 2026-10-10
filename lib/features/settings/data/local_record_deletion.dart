import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Deletes only unchanged records reviewed by the user, in one storage write.
class LocalRecordDeletion {
  static Future<int> journal(List<Map<String, dynamic>> reviewed) =>
      _delete('local_journal', reviewed);

  static Future<int> recurring(List<Map<String, dynamic>> reviewed) =>
      _delete('local_recurring', reviewed);

  static Future<int> _delete(
      String key, List<Map<String, dynamic>> reviewed) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || reviewed.isEmpty) return 0;
    final expected = {for (final row in reviewed) row['id']: row};
    final rows = (jsonDecode(raw) as List).cast<Map>();
    final remaining = rows.where((row) {
      final snapshot = expected[row['id']];
      return snapshot == null ||
          !snapshot.entries.every(
              (field) => jsonEncode(row[field.key]) == jsonEncode(field.value));
    }).toList();
    final count = rows.length - remaining.length;
    if (count > 0 && !await prefs.setString(key, jsonEncode(remaining))) {
      throw StateError('Não foi possível salvar a exclusão local.');
    }
    return count;
  }
}
