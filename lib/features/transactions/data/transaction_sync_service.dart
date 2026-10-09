import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'transaction_model.dart';

abstract class TransactionRemote {
  Future<List<Map<String, dynamic>>> fetch(String userId);
  Future<void> save(String userId, Map<String, dynamic> entry);
}

/// Account-scoped cache and durable outbox. Legacy data needs explicit import.
class TransactionSyncService {
  TransactionSyncService({this.userId, this.remote});

  final String? userId;
  final TransactionRemote? remote;
  Future<void> _serial = Future<void>.value();
  Future<void>? _syncing;

  String get _key =>
      userId == null ? 'local_transactions' : 'transactions:v1:user:$userId';

  Future<T> _locked<T>(Future<T> Function() action) {
    final next = _serial.then((_) => action());
    _serial = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<List<Map<String, dynamic>>> _readEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final values = (jsonDecode(raw) as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    if (userId == null) {
      return values
          .map((value) => {
                'id': value['id'],
                'payload': value,
                'is_deleted': false,
                'pending': false,
                'revision': 'guest'
              })
          .toList();
    }
    return values;
  }

  Future<void> _store(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final values = userId == null
        ? entries
            .where((e) => e['is_deleted'] != true)
            .map((e) => e['payload'])
            .toList()
        : entries;
    if (!await prefs.setString(_key, jsonEncode(values))) {
      throw StateError(
          'Não foi possível salvar os lançamentos neste dispositivo');
    }
  }

  Future<List<TransactionModel>> getAll() => _locked(() async {
        final entries = await _readEntries();
        return entries
            .where((e) => e['is_deleted'] != true)
            .map((e) => TransactionModel.fromJson(
                Map<String, dynamic>.from(e['payload'] as Map)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      });

  Future<void> save(TransactionModel tx) => _change(tx.id, tx.toJson());
  Future<void> delete(String id) => _change(id, null);

  Future<void> _change(String id, Map<String, dynamic>? payload) =>
      _locked(() async {
        final entries = await _readEntries();
        entries.removeWhere((entry) => entry['id'] == id);
        entries.add({
          'id': id,
          'payload': payload,
          'is_deleted': payload == null,
          'pending': userId != null,
          'revision': const Uuid().v4()
        });
        await _store(entries);
      });

  Future<int> pendingCount() => _locked(() async =>
      (await _readEntries()).where((entry) => entry['pending'] == true).length);

  Future<int> legacyCount() async {
    if (userId == null) return 0;
    final legacy = TransactionSyncService();
    final rows = await legacy.getAll();
    final entries = await _locked(_readEntries);
    final known = entries.map((entry) => entry['id']).toSet();
    return rows.where((tx) => !known.contains(tx.id)).length;
  }

  /// Preserve the original data. Stable IDs make repeated imports idempotent.
  Future<void> importLegacy() async {
    if (userId == null) return;
    final legacy = await TransactionSyncService().getAll();
    await _locked(() async {
      final entries = await _readEntries();
      final ids = entries.map((entry) => entry['id']).toSet();
      for (final tx in legacy) {
        if (ids.add(tx.id)) {
          entries.add({
            'id': tx.id,
            'payload': tx.toJson(),
            'is_deleted': false,
            'pending': true,
            'revision': const Uuid().v4()
          });
        }
      }
      await _store(entries);
    });
  }

  Future<void> synchronize() {
    if (userId == null || remote == null) return Future<void>.value();
    return _syncing ??= _synchronize().whenComplete(() => _syncing = null);
  }

  Future<void> _synchronize() async {
    final owner = userId!;
    final snapshot = await _locked(_readEntries);
    for (final entry in snapshot.where((e) => e['pending'] == true)) {
      await remote!.save(owner, entry);
      await _locked(() async {
        final current = await _readEntries();
        for (final item in current) {
          if (item['id'] == entry['id'] &&
              item['revision'] == entry['revision']) {
            item['pending'] = false;
          }
        }
        await _store(current);
      });
    }
    final cloud = await remote!.fetch(owner);
    await _locked(() async {
      final local = await _readEntries();
      final merged = {
        for (final entry in cloud)
          entry['id']: {...entry, 'pending': false, 'revision': 'cloud'}
      };
      // Edits made while a request was in flight always stay in the outbox.
      for (final entry in local.where((e) => e['pending'] == true)) {
        merged[entry['id']] = entry;
      }
      await _store(merged.values.toList());
    });
  }
}
