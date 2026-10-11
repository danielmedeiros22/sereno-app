import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/financial_record_sync_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/local_recurring_service.dart';
import '../../data/recurring_model.dart';

final localRecurringServiceProvider = Provider<LocalRecurringService>((ref) =>
    LocalRecurringService(
        owner: ref.watch(transactionOwnerProvider),
        remote: ref.watch(financialRecordRemoteProvider)));
final recurringListProvider = StateNotifierProvider<RecurringListNotifier,
    AsyncValue<List<RecurringModel>>>((ref) {
  final service = ref.watch(localRecurringServiceProvider);
  final notifier = RecurringListNotifier(
      service,
      (failed) => ref
          .read(financialSyncFailedProvider('recurring').notifier)
          .state = failed);
  installFinancialSync(ref, service.store.remote, notifier.synchronize);
  return notifier;
});

class RecurringListNotifier extends FinancialListNotifier<RecurringModel> {
  RecurringListNotifier(this.service, void Function(bool) onFailure)
      : super(onFailure) {
    initialize();
  }
  final LocalRecurringService service;
  @override
  Future<List<RecurringModel>> readRecords() => service.getAll();
  @override
  Future<void> syncRecords() => service.synchronize();
  Future<void> add(RecurringModel rule) async {
    await service.add(rule);
    await changed();
  }

  Future<void> remove(String id) async {
    await service.delete(id);
    await changed();
  }

  Future<void> toggleActive(RecurringModel rule) async {
    await service.update(rule.copyWith(active: !rule.active));
    await changed();
  }

  Future<int> deleteReviewed(List<RecurringModel> rows) async {
    final count = await service.deleteReviewed(rows);
    await load();
    await synchronize();
    return count;
  }

  Future<void> setPaid(String id, String month, bool paid) async {
    if (paid) {
      await service.markPaid(id, month);
    } else {
      await service.unmarkPaid(id, month);
    }
    await changed();
  }
}

final paidIdsProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(recurringListProvider);
  final service = ref.watch(localRecurringServiceProvider);
  return service.getPaidIds(service.currentMonthKey());
});
