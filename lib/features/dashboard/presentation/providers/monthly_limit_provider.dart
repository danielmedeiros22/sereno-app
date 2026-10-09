import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/guest_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/monthly_limit_service.dart';
import '../../data/supabase_monthly_limit_remote.dart';

final monthlyLimitOwnerProvider = Provider<String?>((ref) {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(isGuestProvider) ? null : userId;
});

final monthlyLimitServiceProvider = Provider<MonthlyLimitService>((ref) {
  final owner = ref.watch(monthlyLimitOwnerProvider);
  return MonthlyLimitService(
    userId: owner,
    remote: owner == null || dotenv.env['MONTHLY_LIMIT_CLOUD_SYNC'] != 'true'
        ? null
        : SupabaseMonthlyLimitRemote(SupabaseService.client),
  );
});

class MonthlyLimitState {
  const MonthlyLimitState(this.record,
      {this.syncing = false, this.syncFailed = false});

  final MonthlyLimitRecord record;
  final bool syncing;
  final bool syncFailed;
}

final monthlyLimitProvider = StateNotifierProvider.autoDispose<
    MonthlyLimitNotifier, AsyncValue<MonthlyLimitState>>((ref) {
  final service = ref.watch(monthlyLimitServiceProvider);
  final notifier = MonthlyLimitNotifier(service);
  if (service.userId != null && service.remote != null) {
    final connection = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(notifier.synchronize());
      }
    });
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(notifier.synchronize());
    });
    ref.onDispose(() {
      connection.cancel();
      timer.cancel();
    });
  }
  return notifier;
});

class MonthlyLimitNotifier
    extends StateNotifier<AsyncValue<MonthlyLimitState>> {
  MonthlyLimitNotifier(this.service) : super(const AsyncValue.loading()) {
    ready = _load();
  }

  final MonthlyLimitService service;
  late final Future<void> ready;
  Timer? _debounce;
  int _edits = 0;
  bool _syncing = false;

  Future<void> _load() async {
    try {
      final record = await service.read();
      if (!mounted) return;
      state = AsyncValue.data(MonthlyLimitState(record));
      unawaited(synchronize());
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
    }
  }

  Future<void> save(double value) async {
    final edit = ++_edits;
    await service.save(value);
    final record = await service.read();
    if (!mounted || edit != _edits) return;
    state = AsyncValue.data(MonthlyLimitState(record));
    _debounce?.cancel();
    if (service.userId != null && service.remote != null) {
      _debounce = Timer(const Duration(milliseconds: 600), () {
        unawaited(synchronize());
      });
    }
  }

  Future<void> synchronize() async {
    if (!mounted ||
        _syncing ||
        service.userId == null ||
        service.remote == null) {
      return;
    }
    final current = state.valueOrNull;
    if (current == null) return;
    _syncing = true;
    final edits = _edits;
    state = AsyncValue.data(MonthlyLimitState(current.record, syncing: true));
    try {
      final record = await service.synchronize();
      if (mounted && edits == _edits) {
        state = AsyncValue.data(MonthlyLimitState(record));
      }
    } catch (_) {
      if (mounted && edits == _edits) {
        state = AsyncValue.data(
            MonthlyLimitState(current.record, syncFailed: true));
      }
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
