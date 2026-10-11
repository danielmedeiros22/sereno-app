import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/category_service.dart';
import '../../data/default_categories.dart';
import '../../data/supabase_category_remote.dart';
import 'transaction_provider.dart';

final categoryServiceProvider = Provider<CategoryService>((ref) {
  final owner = ref.watch(transactionOwnerProvider);
  return CategoryService(
      owner: owner,
      remote: owner == null
          ? null
          : SupabaseCategoryRemote(SupabaseService.client));
});

final categorySyncFailedProvider = StateProvider<bool>((ref) {
  ref.watch(transactionOwnerProvider);
  return false;
});

final categoryListProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<List<CategoryItem>>>(
        (ref) {
  final service = ref.watch(categoryServiceProvider);
  final notifier = CategoryNotifier(service,
      (failed) => ref.read(categorySyncFailedProvider.notifier).state = failed);
  if (service.remote != null) {
    final timer = Timer.periodic(
        const Duration(seconds: 30), (_) => notifier.synchronize());
    final subscription = Connectivity().onConnectivityChanged.listen((values) {
      if (values.any((v) => v != ConnectivityResult.none)) {
        notifier.synchronize();
      }
    });
    ref.onDispose(() {
      timer.cancel();
      subscription.cancel();
    });
  }
  return notifier;
});

final availableCategoriesProvider = Provider<List<CategoryItem>>((ref) {
  final definitions = <String, CategoryItem>{
    for (final item in defaultCategories) item.key: item,
    for (final item
        in ref.watch(categoryListProvider).valueOrNull ?? <CategoryItem>[])
      item.key: item,
  };
  return definitions.values.toList();
});

class CategoryNotifier extends StateNotifier<AsyncValue<List<CategoryItem>>> {
  CategoryNotifier(this.service, this.onFailure)
      : super(const AsyncValue.loading()) {
    ready = _initialize();
  }
  final CategoryService service;
  final void Function(bool) onFailure;
  late final Future<void> ready;
  Future<void>? _sync;
  Future<void> _initialize() async {
    await load();
    await synchronize();
  }

  Future<void> load() async {
    try {
      final list = await service.getAll();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, s) {
      if (mounted) state = AsyncValue.error(e, s);
    }
  }

  Future<CategoryItem> add(String name, String icon, String type) async {
    final item = await service.add(name, icon, type);
    await load();
    unawaited(synchronize());
    return item;
  }

  Future<void> synchronize() {
    if (!mounted) return Future.value();
    return _sync ??= _synchronize().whenComplete(() => _sync = null);
  }

  Future<void> _synchronize() async {
    try {
      await service.synchronize();
      await load();
      if (mounted) onFailure(false);
    } catch (_) {
      if (mounted) onFailure(true);
    }
  }
}
