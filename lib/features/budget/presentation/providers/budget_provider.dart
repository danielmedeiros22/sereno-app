import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/financial_record_sync_provider.dart';
import '../../data/local_budget_service.dart';
import '../../data/budget_model.dart';
import '../../../transactions/data/default_categories.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

final localBudgetServiceProvider = Provider<LocalBudgetService>((ref) =>
    LocalBudgetService(
        owner: ref.watch(transactionOwnerProvider),
        remote: ref.watch(financialRecordRemoteProvider)));
final budgetListProvider =
    StateNotifierProvider<BudgetListNotifier, AsyncValue<List<BudgetModel>>>(
        (ref) {
  final service = ref.watch(localBudgetServiceProvider);
  final notifier = BudgetListNotifier(
      service,
      (failed) => ref
          .read(financialSyncFailedProvider('budget').notifier)
          .state = failed);
  installFinancialSync(ref, service.store.remote, notifier.synchronize);
  return notifier;
});

class BudgetListNotifier extends FinancialListNotifier<BudgetModel> {
  BudgetListNotifier(this.service, void Function(bool) onFailure)
      : super(onFailure) {
    initialize();
  }
  final LocalBudgetService service;
  @override
  Future<List<BudgetModel>> readRecords() => service.getAll();
  @override
  Future<void> syncRecords() => service.synchronize();
  Future<void> add(BudgetModel budget) async {
    await service.add(budget);
    await changed();
  }

  Future<void> remove(String id) async {
    await service.delete(id);
    await changed();
  }
}

final categorySpentProvider = Provider<AsyncValue<Map<String, double>>>(
    (ref) => ref.watch(transactionListProvider).whenData((all) {
          final now = DateTime.now();
          final spent = <String, double>{};
          for (final tx in all.where((t) =>
              t.isExpense &&
              t.date.toLocal().year == now.year &&
              t.date.toLocal().month == now.month)) {
            final key = categoryNameKey(tx.category);
            spent[key] = (spent[key] ?? 0) + tx.amount;
          }
          return spent;
        }));
