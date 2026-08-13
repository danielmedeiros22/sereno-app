import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_budget_service.dart';
import '../../data/budget_model.dart';
import '../../../transactions/data/local_transaction_service.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

final localBudgetServiceProvider = Provider<LocalBudgetService>((ref) {
  return LocalBudgetService();
});

final budgetListProvider =
    StateNotifierProvider<BudgetListNotifier, AsyncValue<List<BudgetModel>>>((ref) {
  return BudgetListNotifier(ref.read(localBudgetServiceProvider));
});

class BudgetListNotifier extends StateNotifier<AsyncValue<List<BudgetModel>>> {
  final LocalBudgetService _service;

  BudgetListNotifier(this._service) : super(const AsyncValue.loading()) {
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

  Future<void> add(BudgetModel budget) async {
    await _service.add(budget);
    await load();
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    await load();
  }
}

final categorySpentProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(transactionListProvider);
  final service = LocalTransactionService();
  final all = await service.getAll();
  final now = DateTime.now();
  final monthTxs = all.where((t) =>
      t.isExpense && t.date.year == now.year && t.date.month == now.month);

  final Map<String, double> spent = {};
  for (final tx in monthTxs) {
    spent[tx.category] = (spent[tx.category] ?? 0) + tx.amount;
  }
  return spent;
});