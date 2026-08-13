import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_recurring_service.dart';
import '../../data/recurring_model.dart';

final localRecurringServiceProvider = Provider<LocalRecurringService>((ref) {
  return LocalRecurringService();
});

final recurringListProvider =
    StateNotifierProvider<RecurringListNotifier, AsyncValue<List<RecurringModel>>>((ref) {
  return RecurringListNotifier(ref.read(localRecurringServiceProvider));
});

class RecurringListNotifier extends StateNotifier<AsyncValue<List<RecurringModel>>> {
  final LocalRecurringService _service;

  RecurringListNotifier(this._service) : super(const AsyncValue.loading()) {
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

  Future<void> add(RecurringModel rule) async {
    await _service.add(rule);
    await load();
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    await load();
  }

  Future<void> toggleActive(RecurringModel rule) async {
    await _service.update(rule.copyWith(active: !rule.active));
    await load();
  }
}

final paidIdsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(recurringListProvider);
  final service = ref.read(localRecurringServiceProvider);
  return service.getPaidIds(service.currentMonthKey());
});