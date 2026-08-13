import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncOperation {
  final String id;
  final String table;
  final String action; // insert, update, delete
  final Map<String, dynamic> data;
  final DateTime createdAt;

  SyncOperation({
    required this.id,
    required this.table,
    required this.action,
    required this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'action': action,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'],
      table: json['table'],
      action: json['action'],
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class SyncQueue {
  static const _key = 'sync_queue';

  Future<List<SyncOperation>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => SyncOperation.fromJson(e)).toList();
  }

  Future<void> add(SyncOperation op) async {
    final all = await getAll();
    all.add(op);
    await _save(all);
  }

  Future<void> remove(String id) async {
    final all = await getAll();
    all.removeWhere((op) => op.id == id);
    await _save(all);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<int> get pendingCount async {
    final all = await getAll();
    return all.length;
  }

  Future<void> _save(List<SyncOperation> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}