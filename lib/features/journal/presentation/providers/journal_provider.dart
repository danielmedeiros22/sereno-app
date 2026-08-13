import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_journal_service.dart';
import '../../data/journal_model.dart';

final localJournalServiceProvider = Provider<LocalJournalService>((ref) {
  return LocalJournalService();
});

final journalListProvider =
    StateNotifierProvider<JournalListNotifier, AsyncValue<List<JournalEntry>>>((ref) {
  return JournalListNotifier(ref.read(localJournalServiceProvider));
});

class JournalListNotifier extends StateNotifier<AsyncValue<List<JournalEntry>>> {
  final LocalJournalService _service;

  JournalListNotifier(this._service) : super(const AsyncValue.loading()) {
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

  Future<void> add(JournalEntry entry) async {
    await _service.add(entry);
    await load();
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    await load();
  }
}