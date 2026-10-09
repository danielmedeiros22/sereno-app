import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';

class MemoryRemote implements TransactionRemote {
  final rows = <String, Map<String, Map<String, dynamic>>>{};
  bool offline = false;
  Completer<void>? started;
  Completer<void>? release;

  @override
  Future<void> save(String userId, Map<String, dynamic> entry) async {
    if (offline) throw StateError('offline');
    started?.complete();
    started = null;
    await release?.future;
    rows.putIfAbsent(userId, () => {})[entry['id'] as String] =
        Map<String, dynamic>.from(entry);
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String userId) async {
    if (offline) throw StateError('offline');
    return rows[userId]?.values.map(Map<String, dynamic>.from).toList() ?? [];
  }
}

TransactionModel tx({String? id, double amount = 50}) => TransactionModel(
    id: id,
    type: 'expense',
    amount: amount,
    category: 'Mercado',
    date: DateTime(2026, 10, 9));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guest data stays local and is not silently assigned to an account',
      () async {
    final guest = TransactionSyncService();
    await guest.save(tx());
    final remote = MemoryRemote();
    final account = TransactionSyncService(userId: 'a', remote: remote);
    await account.synchronize();
    expect(await account.getAll(), isEmpty);
    expect(await guest.getAll(), hasLength(1));
    expect(remote.rows, isEmpty);
    expect(await account.legacyCount(), 1);
  });

  test(
      'explicit import preserves legacy copy and stable IDs without duplicates',
      () async {
    final original = tx();
    SharedPreferences.setMockInitialValues({
      'local_transactions': jsonEncode([original.toJson()])
    });
    final account = TransactionSyncService(userId: 'a', remote: MemoryRemote());
    await account.importLegacy();
    await account.importLegacy();
    await account.synchronize();
    expect((await account.getAll()).single.id, original.id);
    expect(await TransactionSyncService().getAll(), hasLength(1));
  });

  test('account data and pending writes are isolated from other users',
      () async {
    final remote = MemoryRemote();
    final a = TransactionSyncService(userId: 'a', remote: remote);
    final b = TransactionSyncService(userId: 'b', remote: remote);
    await a.save(tx());
    await b.synchronize();
    expect(await b.getAll(), isEmpty);
    expect(await a.pendingCount(), 1);
    expect(remote.rows, isEmpty);
    await a.synchronize();
    expect(remote.rows['a'], hasLength(1));
    expect(remote.rows['b'], isNull);
  });

  test('offline writes survive restart and are uploaded on reconnection',
      () async {
    final remote = MemoryRemote()..offline = true;
    final account = TransactionSyncService(userId: 'a', remote: remote);
    await account.save(tx());
    await expectLater(account.synchronize(), throwsStateError);
    final restarted = TransactionSyncService(userId: 'a', remote: remote);
    expect(await restarted.getAll(), hasLength(1));
    expect(await restarted.pendingCount(), 1);
    remote.offline = false;
    await restarted.synchronize();
    expect(await restarted.pendingCount(), 0);
    expect(remote.rows['a'], hasLength(1));
  });

  test('a clean device pulls records and remote updates', () async {
    final remote = MemoryRemote();
    final first = TransactionSyncService(userId: 'a', remote: remote);
    final original = tx();
    await first.save(original);
    await first.synchronize();
    // Simulate another browser with independent local storage.
    SharedPreferences.setMockInitialValues({});
    final second = TransactionSyncService(userId: 'a', remote: remote);
    await second.synchronize();
    expect((await second.getAll()).single.id, original.id);
    await first.save(tx(id: original.id, amount: 1));
    await first.synchronize();
    await second.synchronize();
    expect((await second.getAll()).single.amount, 1);
  });

  test(
      'deletion propagates and explicit import cannot resurrect cloud tombstone',
      () async {
    final original = tx();
    await TransactionSyncService().save(original);
    final remote = MemoryRemote();
    final account = TransactionSyncService(userId: 'a', remote: remote);
    await account.importLegacy();
    await account.synchronize();
    await account.delete(original.id);
    await account.synchronize();
    SharedPreferences.setMockInitialValues({
      'local_transactions': jsonEncode([original.toJson()])
    });
    final other = TransactionSyncService(userId: 'a', remote: remote);
    await other.synchronize();
    await other.importLegacy();
    expect(await other.getAll(), isEmpty);
    expect(remote.rows['a']![original.id]!['is_deleted'], true);
  });

  test('an edit made during upload stays pending until its own upload succeeds',
      () async {
    final remote = MemoryRemote();
    final account = TransactionSyncService(userId: 'a', remote: remote);
    final original = tx();
    await account.save(original);
    final started = Completer<void>();
    final release = Completer<void>();
    remote.started = started;
    remote.release = release;
    final running = account.synchronize();
    await started.future;
    await account.save(tx(id: original.id, amount: 100));
    release.complete();
    await running;
    expect((await account.getAll()).single.amount, 100);
    expect(await account.pendingCount(), 1);
    await account.synchronize();
    expect(await account.pendingCount(), 0);
    expect((remote.rows['a']![original.id]!['payload'] as Map)['amount'], 100);
  });

  test('parallel saves do not lose local transactions', () async {
    final account = TransactionSyncService(userId: 'a');
    await Future.wait(List.generate(20, (_) => account.save(tx())));
    expect(await account.getAll(), hasLength(20));
    expect(await account.pendingCount(), 20);
  });
}
