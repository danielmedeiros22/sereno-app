import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/supabase_client.dart';
import '../../features/transactions/presentation/providers/transaction_provider.dart';
import 'account_record_store.dart';

final financialRecordRemoteProvider = Provider<AccountRecordRemote?>((ref) =>
    ref.watch(transactionOwnerProvider) == null
        ? null
        : SupabaseAccountRecordRemote(SupabaseService.client));

final financialSyncFailedProvider =
    StateProvider.family<bool, String>((ref, kind) {
  ref.watch(transactionOwnerProvider);
  return false;
});

void installFinancialSync(
    Ref ref, AccountRecordRemote? remote, Future<void> Function() sync) {
  if (remote == null) return;
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
  final connection = Connectivity().onConnectivityChanged.listen((values) {
    if (values.any((v) => v != ConnectivityResult.none)) sync();
  });
  ref.onDispose(() {
    timer.cancel();
    connection.cancel();
  });
}

abstract class FinancialListNotifier<T>
    extends StateNotifier<AsyncValue<List<T>>> {
  FinancialListNotifier(this.onFailure) : super(const AsyncValue.loading());
  final void Function(bool) onFailure;
  Future<List<T>> readRecords();
  Future<void> syncRecords();
  Future<void>? _sync;
  Future<void> initialize() async {
    await load();
    await synchronize();
  }

  Future<void> load() async {
    try {
      final rows = await readRecords();
      if (mounted) state = AsyncValue.data(rows);
    } catch (e, s) {
      if (mounted) state = AsyncValue.error(e, s);
    }
  }

  Future<void> synchronize() {
    if (!mounted) return Future.value();
    return _sync ??= _synchronize().whenComplete(() => _sync = null);
  }

  Future<void> _synchronize() async {
    try {
      await syncRecords();
      await load();
      if (mounted) onFailure(false);
    } catch (_) {
      if (mounted) onFailure(true);
    }
  }

  Future<void> changed() async {
    await load();
    unawaited(synchronize());
  }
}
