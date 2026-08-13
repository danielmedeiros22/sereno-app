import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_transaction_service.dart';
import '../../data/transaction_model.dart';

final localTransactionServiceProvider = Provider<LocalTransactionService>((ref) {
  return LocalTransactionService();
});

final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionListNotifier(ref.read(localTransactionServiceProvider));
});

class TransactionListNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final LocalTransactionService _service;

  TransactionListNotifier(this._service) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.getAll();
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(TransactionModel tx) async {
    await _service.add(tx);
    await load();
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    await load();
  }

  Future<void> update(TransactionModel tx) async {
    await _service.update(tx);
    await load();
  }
}

final monthTotalsProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(transactionListProvider);
  final service = ref.read(localTransactionServiceProvider);
  return service.getMonthTotals();
});
