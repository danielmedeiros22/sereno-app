import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../recurring/data/recurring_schedule.dart';
import '../../../dashboard/presentation/providers/monthly_limit_provider.dart';
import '../../data/notification_preferences.dart';
import '../../data/notification_engine.dart';

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) =>
        NotificationPreferencesService(ref.watch(transactionOwnerProvider)));
final notificationPreferencesProvider = StateNotifierProvider<
        NotificationPreferencesNotifier, AsyncValue<NotificationPreferences>>(
    (ref) => NotificationPreferencesNotifier(
        ref.watch(notificationPreferencesServiceProvider)));

class NotificationPreferencesNotifier
    extends StateNotifier<AsyncValue<NotificationPreferences>> {
  NotificationPreferencesNotifier(this.service)
      : super(const AsyncValue.loading()) {
    ready = _load();
  }
  final NotificationPreferencesService service;
  late final Future<void> ready;
  Future<void> _load() async {
    try {
      final value = await service.read();
      if (mounted) state = AsyncValue.data(value);
    } catch (e, s) {
      if (mounted) state = AsyncValue.error(e, s);
    }
  }

  Future<void> save(NotificationPreferences value) async {
    await ready;
    await service.save(value);
    if (mounted) state = AsyncValue.data(value);
  }
}

final notificationDateProvider = Provider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    final latest = DateTime.now();
    if (latest.year != now.year ||
        latest.month != now.month ||
        latest.day != now.day) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(timer.cancel);
  return calendarDay(now);
});

final notificationPaymentsProvider =
    FutureProvider.autoDispose<Map<String, Set<String>>>((ref) async {
  final rules = ref.watch(recurringListProvider).valueOrNull ?? [];
  final today = ref.watch(notificationDateProvider);
  final days =
      ref.watch(notificationPreferencesProvider).valueOrNull?.daysBefore ?? 3;
  final service = ref.watch(localRecurringServiceProvider);
  final months = rules
      .where((r) => r.active)
      .expand((r) => relevantDueDates(r, today, days))
      .map(paymentMonth)
      .toSet();
  return {for (final month in months) month: await service.getPaidIds(month)};
});

final serenoAlertsProvider =
    Provider.autoDispose<AsyncValue<List<SerenoAlert>>>((ref) {
  final now = ref.watch(notificationDateProvider);
  final prefs = ref.watch(notificationPreferencesProvider);
  final transactions = ref.watch(transactionListProvider);
  final limit = ref.watch(monthlyLimitProvider);
  final budgets = ref.watch(budgetListProvider);
  final bills = ref.watch(recurringListProvider);
  final paid = ref.watch(notificationPaymentsProvider);
  final sources = <AsyncValue<dynamic>>[
    prefs,
    transactions,
    limit,
    budgets,
    bills,
    paid
  ];
  for (final source in sources) {
    if (source.hasError) {
      return AsyncValue.error(
          source.error!, source.stackTrace ?? StackTrace.current);
    }
  }
  if (sources.any((source) => source.isLoading)) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(buildSerenoAlerts(
      now: now,
      transactions: transactions.requireValue,
      monthlyLimit: limit.requireValue.record.value,
      budgets: budgets.requireValue,
      bills: bills.requireValue,
      paidByMonth: paid.requireValue,
      preferences: prefs.requireValue));
});
