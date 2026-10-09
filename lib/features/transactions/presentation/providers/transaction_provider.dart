import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/guest_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/supabase_transaction_remote.dart';
import '../../data/transaction_sync_service.dart';
import '../../data/transaction_model.dart';

final transactionOwnerProvider = Provider<String?>((ref) {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(isGuestProvider) ? null : userId;
});

final localTransactionServiceProvider = Provider<TransactionSyncService>((ref) {
  final owner = ref.watch(transactionOwnerProvider);
  return TransactionSyncService(
      userId: owner,
      remote: owner != null && dotenv.env['TRANSACTION_CLOUD_SYNC'] == 'true'
          ? SupabaseTransactionRemote(SupabaseService.client)
          : null);
});

enum TransactionSyncStatus { local, syncing, synced, failed, disabled }

final transactionSyncStatusProvider =
    StateProvider<TransactionSyncStatus>((ref) {
  final service = ref.watch(localTransactionServiceProvider);
  return service.userId == null
      ? TransactionSyncStatus.local
      : service.remote == null
          ? TransactionSyncStatus.disabled
          : TransactionSyncStatus.syncing;
});

final legacyTransactionCountProvider = FutureProvider<int>((ref) {
  ref.watch(transactionListProvider);
  return ref.watch(localTransactionServiceProvider).legacyCount();
});

final transactionListProvider = StateNotifierProvider<TransactionListNotifier,
    AsyncValue<List<TransactionModel>>>((ref) {
  final service = ref.watch(localTransactionServiceProvider);
  final notifier = TransactionListNotifier(service, (status) {
    ref.read(transactionSyncStatusProvider.notifier).state = status;
  });
  if (service.userId != null && service.remote != null) {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(notifier.synchronize());
    });
    final subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(notifier.synchronize());
      }
    });
    ref.onDispose(() {
      timer.cancel();
      subscription.cancel();
    });
  }
  return notifier;
});

class TransactionListNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionSyncService _service;
  final void Function(TransactionSyncStatus) _setStatus;
  bool _syncing = false;
  int _edits = 0;

  TransactionListNotifier(this._service, this._setStatus)
      : super(const AsyncValue.loading()) {
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await load();
    await synchronize();
  }

  Future<void> load() async {
    try {
      final list = await _service.getAll();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, s) {
      if (mounted) state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(TransactionModel tx) async {
    ++_edits;
    await _service.save(tx);
    await load();
    unawaited(synchronize());
  }

  Future<void> remove(String id) async {
    ++_edits;
    await _service.delete(id);
    await load();
    unawaited(synchronize());
  }

  Future<void> update(TransactionModel tx) async {
    await add(tx);
  }

  Future<void> importLegacy() async {
    // Fetch cloud IDs first so import cannot replace an existing cloud record.
    if (_service.remote != null) await _service.synchronize();
    await _service.importLegacy();
    ++_edits;
    await load();
    unawaited(synchronize());
  }

  Future<void> synchronize() async {
    if (!mounted || _syncing || _service.remote == null) return;
    _syncing = true;
    _setStatus(TransactionSyncStatus.syncing);
    final edits = _edits;
    try {
      await _service.synchronize();
      if (mounted) {
        await load();
        final pending = await _service.pendingCount();
        if (mounted) {
          _setStatus(pending == 0
              ? TransactionSyncStatus.synced
              : TransactionSyncStatus.syncing);
        }
      }
    } catch (_) {
      if (mounted) _setStatus(TransactionSyncStatus.failed);
    } finally {
      _syncing = false;
      if (mounted && edits != _edits) unawaited(synchronize());
    }
  }
}

final monthTotalsProvider = FutureProvider<Map<String, double>>((ref) async {
  final transactions =
      ref.watch(transactionListProvider).valueOrNull ?? <TransactionModel>[];
  final now = DateTime.now();
  double income = 0, expense = 0;
  for (final tx in transactions
      .where((tx) => tx.date.year == now.year && tx.date.month == now.month)) {
    if (tx.isIncome) {
      income += tx.amount;
    } else {
      expense += tx.amount;
    }
  }
  return {'income': income, 'expense': expense, 'balance': income - expense};
});
