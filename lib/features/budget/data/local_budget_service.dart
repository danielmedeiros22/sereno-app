import '../../../../core/services/account_record_store.dart';
import '../../transactions/data/default_categories.dart';
import 'budget_model.dart';

class LocalBudgetService {
  LocalBudgetService({String? owner, AccountRecordRemote? remote})
      : store = AccountRecordStore(
            kind: 'budget',
            guestKey: 'local_budgets',
            owner: owner,
            remote: remote);
  final AccountRecordStore store;
  Future<List<BudgetModel>> getAll() async =>
      (await store.getAll()).map(BudgetModel.fromJson).toList()
        ..sort((a, b) => a.category.compareTo(b.category));
  Future<void> add(BudgetModel budget) async {
    final row = budget.toJson();
    final existing = (await getAll()).where(
        (b) => categoryNameKey(b.category) == categoryNameKey(budget.category));
    row['id'] = existing.isEmpty
        ? 'category:${categoryNameKey(budget.category)}'
        : existing.first.id;
    await store.save(row);
  }

  Future<void> delete(String id) => store.delete(id);
  Future<void> synchronize() => store.synchronize();
}
