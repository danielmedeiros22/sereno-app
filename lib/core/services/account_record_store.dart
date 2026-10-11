import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

abstract class AccountRecordRemote {
  Future<List<Map<String, dynamic>>> fetch(String owner, String kind);
  Future<void> save(String owner, String kind, Map<String, dynamic> entry);
}

class SupabaseAccountRecordRemote implements AccountRecordRemote {
  SupabaseAccountRecordRemote(this.client);
  final SupabaseClient client;
  void _check(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('A conta mudou.');
    }
  }

  @override
  Future<void> save(
      String owner, String kind, Map<String, dynamic> entry) async {
    _check(owner);
    await client.from('account_financial_records').upsert({
      'user_id': owner,
      'kind': kind,
      'id': entry['id'],
      'payload': entry['payload'],
      'is_deleted': entry['is_deleted'],
    }, onConflict: 'user_id,kind,id');
    _check(owner);
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String owner, String kind) async {
    final all = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 500) {
      _check(owner);
      final rows = await client
          .from('account_financial_records')
          .select('id,payload,is_deleted')
          .eq('user_id', owner)
          .eq('kind', kind)
          .order('id')
          .range(offset, offset + 499);
      _check(owner);
      all.addAll(rows);
      if (rows.length < 500) break;
    }
    return all;
  }
}

/// Durable per-account outbox; guest records keep their historical storage key.
class AccountRecordStore {
  AccountRecordStore(
      {required this.kind, required this.guestKey, this.owner, this.remote});
  final String kind;
  final String guestKey;
  final String? owner;
  final AccountRecordRemote? remote;
  Future<void> _serial = Future.value();
  Future<void>? _sync;
  String get _key => owner == null ? guestKey : 'records:v1:$kind:user:$owner';
  Future<T> _locked<T>(Future<T> Function() action) {
    final next = _serial.then((_) => action());
    _serial = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    final rows = (jsonDecode(raw) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return owner == null
        ? rows
            .map((row) => <String, dynamic>{
                  'id': row['id'],
                  'payload': row,
                  'is_deleted': false,
                  'pending': false,
                })
            .toList()
        : rows;
  }

  Future<void> _write(List<Map<String, dynamic>> rows) async {
    final values = owner == null
        ? rows
            .where((r) => r['is_deleted'] != true)
            .map((r) => r['payload'])
            .toList()
        : rows;
    if (!await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(values))) {
      throw StateError('Não foi possível salvar neste dispositivo.');
    }
  }

  Future<List<Map<String, dynamic>>> getAll() =>
      _locked(() async => (await _read())
          .where((r) => r['is_deleted'] != true)
          .map((r) => Map<String, dynamic>.from(r['payload'] as Map))
          .toList());
  Future<int> pendingCount() => _locked(
      () async => (await _read()).where((r) => r['pending'] == true).length);
  Future<void> save(Map<String, dynamic> row) =>
      _change(row['id'] as String, row);
  Future<Set<String>> knownIds() => _locked(
      () async => (await _read()).map((row) => row['id'] as String).toSet());
  Future<void> delete(String id) => _change(id, null);
  Map<String, dynamic> _entry(String id, Map<String, dynamic>? payload) => {
        'id': id,
        'payload': payload,
        'is_deleted': payload == null,
        'pending': owner != null,
        'revision': const Uuid().v4(),
      };
  Future<void> _change(String id, Map<String, dynamic>? payload) =>
      _locked(() async {
        final rows = await _read();
        rows.removeWhere((r) => r['id'] == id);
        rows.add(_entry(id, payload));
        await _write(rows);
      });
  Future<int> deleteReviewed(List<Map<String, dynamic>> reviewed) =>
      _locked(() async {
        final expected = {for (final row in reviewed) row['id']: row};
        final rows = await _read();
        var count = 0;
        for (var i = 0; i < rows.length; i++) {
          if (rows[i]['is_deleted'] != true &&
              expected.containsKey(rows[i]['id']) &&
              expected[rows[i]['id']]!.entries.every((field) =>
                  jsonEncode((rows[i]['payload'] as Map)[field.key]) ==
                  jsonEncode(field.value))) {
            rows[i] = _entry(rows[i]['id'] as String, null);
            count++;
          }
        }
        if (count > 0) await _write(rows);
        return count;
      });
  Future<void> synchronize() {
    if (owner == null || remote == null) return Future.value();
    return _sync ??= _synchronize().whenComplete(() => _sync = null);
  }

  Future<void> _synchronize() async {
    final snapshot = await _locked(_read);
    for (final row in snapshot.where((r) => r['pending'] == true)) {
      await remote!.save(owner!, kind, row);
      await _locked(() async {
        final current = await _read();
        for (final entry in current) {
          if (entry['id'] == row['id'] &&
              entry['revision'] == row['revision']) {
            entry['pending'] = false;
          }
        }
        await _write(current);
      });
    }
    final cloud = await remote!.fetch(owner!, kind);
    await _locked(() async {
      final local = await _read();
      final merged = {
        for (final row in cloud) row['id']: {...row, 'pending': false}
      };
      for (final row in local.where((r) => r['pending'] == true)) {
        merged[row['id']] = row;
      }
      await _write(merged.values.toList());
    });
  }
}
