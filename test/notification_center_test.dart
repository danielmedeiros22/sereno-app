import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/budget/data/budget_model.dart';
import 'package:sereno_app/features/budget/presentation/providers/budget_provider.dart';
import 'package:sereno_app/features/dashboard/data/monthly_limit_service.dart';
import 'package:sereno_app/features/dashboard/presentation/providers/monthly_limit_provider.dart';
import 'package:sereno_app/features/notifications/data/notification_engine.dart';
import 'package:sereno_app/features/notifications/data/notification_preferences.dart';
import 'package:sereno_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:sereno_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:sereno_app/features/recurring/data/local_recurring_service.dart';
import 'package:sereno_app/features/recurring/data/recurring_model.dart';
import 'package:sereno_app/features/recurring/data/recurring_schedule.dart';
import 'package:sereno_app/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:sereno_app/features/transactions/presentation/providers/summary_period.dart';

RecurringModel bill(
        {String id = 'bill',
        int day = 12,
        RecurringFrequency frequency = RecurringFrequency.monthly,
        DateTime? first,
        bool active = true}) =>
    RecurringModel(
        id: id,
        name: 'Internet',
        amount: 100,
        category: 'Assinaturas',
        dueDay: day,
        frequency: frequency,
        firstDueDate: first,
        active: active);

List<SerenoAlert> alerts(
        {DateTime? now,
        List<TransactionModel> transactions = const [],
        double limit = 100,
        List<BudgetModel> budgets = const [],
        List<RecurringModel> bills = const [],
        Map<String, Set<String>> paid = const {},
        NotificationPreferences preferences =
            const NotificationPreferences()}) =>
    buildSerenoAlerts(
        now: now ?? DateTime(2026, 10, 10),
        transactions: transactions,
        monthlyLimit: limit,
        budgets: budgets,
        bills: bills,
        paidByMonth: paid,
        preferences: preferences);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'limits use current month expenses and stable category keys, with one alert per budget',
      () {
    final txs = [
      TransactionModel(
          type: 'expense',
          amount: 90,
          category: 'Café',
          date: DateTime(2026, 10, 1)),
      TransactionModel(
          type: 'income',
          amount: 999,
          category: 'Café',
          date: DateTime(2026, 10, 1)),
      TransactionModel(
          type: 'expense',
          amount: 999,
          category: 'Café',
          date: DateTime(2026, 9, 30)),
    ];
    final result = alerts(transactions: txs, budgets: [
      BudgetModel(id: 'cafe', category: 'CAFÉ', categoryIcon: '☕', limit: 100)
    ]);
    expect(result, hasLength(2));
    expect(result.every((a) => a.message.contains('90%')), true);
    expect(result.map((a) => a.id).toSet(), hasLength(2));
    expect(
        alerts(
            transactions: txs,
            preferences: const NotificationPreferences(threshold: 100)),
        isEmpty);
    expect(alerts(transactions: txs, limit: 50).single.title,
        'Teto mensal ultrapassado');
    expect(alerts(transactions: txs, limit: 90).single.title,
        'Teto mensal atingido');
  });

  test('disabled types and paid or inactive bills produce no alerts', () {
    expect(
        alerts(bills: [
          bill()
        ], paid: {
          '2026-10': {'bill'}
        }),
        isEmpty);
    expect(alerts(bills: [bill(active: false)]), isEmpty);
    expect(
        alerts(
            bills: [bill()],
            preferences: const NotificationPreferences(bills: false)),
        isEmpty);
    expect(
        alerts(
            transactions: [
              TransactionModel(
                  type: 'expense',
                  amount: 100,
                  category: 'Café',
                  date: DateTime(2026, 10, 1))
            ],
            budgets: [
              BudgetModel(category: 'Café', limit: 10)
            ],
            preferences: const NotificationPreferences(
                monthly: false, budgets: false, bills: false)),
        isEmpty);
  });

  test(
      'monthly reminders include overdue, today and the configured future window',
      () {
    expect(alerts(bills: [bill(day: 9)]).single.message,
        contains('atrasada há 1 dia'));
    expect(
        alerts(bills: [bill(day: 10)]).single.message, contains('Vence hoje'));
    expect(alerts(bills: [bill(day: 13)]).single.message,
        contains('Vence em 3 dias'));
    expect(alerts(bills: [bill(day: 14)]), isEmpty);
    expect(
        alerts(
            bills: [bill(day: 11)],
            preferences: const NotificationPreferences(daysBefore: 0)),
        isEmpty);
  });

  test(
      'future month payments do not reuse current month paid flags across year boundary',
      () {
    final result = alerts(now: DateTime(2026, 12, 30), bills: [
      bill(day: 1)
    ], paid: {
      '2026-12': {'bill'}
    });
    expect(result.single.message, contains('01/01/2027'));
    expect(
        alerts(now: DateTime(2026, 12, 30), bills: [
          bill(day: 1)
        ], paid: {
          '2026-12': {'bill'},
          '2027-01': {'bill'}
        }),
        isEmpty);
  });

  test(
      'month ends clamp correctly and first due date prevents premature alerts',
      () {
    expect(
        relevantDueDates(bill(day: 31, first: DateTime(2026, 1, 31)),
            DateTime(2026, 2, 27), 1),
        [DateTime(2026, 2, 28)]);
    expect(
        relevantDueDates(bill(day: 31, first: DateTime(2024, 1, 31)),
            DateTime(2024, 2, 28), 1),
        [DateTime(2024, 2, 29)]);
    expect(alerts(bills: [bill(first: DateTime(2026, 11, 12))]), isEmpty);
  });

  test(
      'weekly, biweekly and yearly schedules use explicit anchor; old nonmonthly rules request setup',
      () {
    expect(
        relevantDueDates(
            bill(
                frequency: RecurringFrequency.weekly,
                first: DateTime(2026, 10, 2)),
            DateTime(2026, 10, 10),
            7),
        [DateTime(2026, 10, 9), DateTime(2026, 10, 16)]);
    expect(
        relevantDueDates(
            bill(
                frequency: RecurringFrequency.biweekly,
                first: DateTime(2026, 10, 2)),
            DateTime(2026, 10, 10),
            7),
        [DateTime(2026, 10, 2), DateTime(2026, 10, 16)]);
    expect(
        relevantDueDates(
            bill(
                frequency: RecurringFrequency.yearly,
                first: DateTime(2024, 2, 29)),
            DateTime(2025, 2, 27),
            1),
        [DateTime(2025, 2, 28)]);
    expect(
        alerts(bills: [bill(frequency: RecurringFrequency.weekly)]).single.type,
        SerenoAlertType.setup);
    expect(
        calendarDifference(
            DateTime(2026, 10, 11), DateTime(2026, 10, 10, 23, 59)),
        1);
  });

  test(
      'preferences survive reopening and stay separated between accounts and visitor',
      () async {
    final service = NotificationPreferencesService('a');
    await service
        .save(const NotificationPreferences(monthly: false, daysBefore: 7));
    expect((await NotificationPreferencesService('a').read()).monthly, false);
    expect((await NotificationPreferencesService('a').read()).daysBefore, 7);
    expect((await NotificationPreferencesService('b').read()).monthly, true);
    expect((await NotificationPreferencesService(null).read()).daysBefore, 3);
  });

  test(
      'first due date survives persistence and activation changes without duplicate rules',
      () async {
    final service = LocalRecurringService();
    final original = bill(first: DateTime(2026, 10, 12));
    await service.add(original);
    final restored = (await service.getAll()).single;
    await service.update(restored.copyWith(active: false));
    expect(await service.getAll(), hasLength(1));
    expect(
        (await service.getAll()).single.firstDueDate, DateTime(2026, 10, 12));
    expect((await service.getAll()).single.active, false);
    expect(
        RecurringModel.fromJson(original.toJson()..remove('firstDueDate'))
            .firstDueDate,
        isNull);
  });

  test('marking paid removes the live alert and unmarking restores it',
      () async {
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      monthlyLimitServiceProvider.overrideWithValue(MonthlyLimitService()),
      notificationDateProvider.overrideWithValue(DateTime(2026, 10, 10)),
    ]);
    addTearDown(container.dispose);
    container.listen(serenoAlertsProvider, (_, __) {});
    await container.read(notificationPreferencesProvider.notifier).ready;
    await container.read(monthlyLimitProvider.notifier).ready;
    await container.read(transactionListProvider.notifier).load();
    await container.read(budgetListProvider.notifier).load();
    final recurring = container.read(recurringListProvider.notifier);
    await recurring.add(bill());
    await recurring.synchronize();
    await container.read(notificationPaymentsProvider.future);
    await container.pump();
    expect(container.read(serenoAlertsProvider).requireValue, hasLength(1));
    await recurring.setPaid('bill', '2026-10', true);
    await recurring.synchronize();
    await container.read(notificationPaymentsProvider.future);
    await container.pump();
    expect(container.read(serenoAlertsProvider).requireValue, isEmpty);
    await recurring.setPaid('bill', '2026-10', false);
    await recurring.synchronize();
    await container.read(notificationPaymentsProvider.future);
    await container.pump();
    expect(container.read(serenoAlertsProvider).requireValue, hasLength(1));
  });

  test('alerts and budget totals follow saved limits and the same transactions',
      () async {
    final now = DateTime.now();
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      monthlyLimitServiceProvider.overrideWithValue(MonthlyLimitService()),
      notificationDateProvider.overrideWithValue(now),
      selectedMonthProvider.overrideWith((ref) => now),
    ]);
    addTearDown(container.dispose);
    container.listen(serenoAlertsProvider, (_, __) {});
    await container.read(notificationPreferencesProvider.notifier).ready;
    final limit = container.read(monthlyLimitProvider.notifier);
    await limit.ready;
    await limit.save(100);
    final transactions = container.read(transactionListProvider.notifier);
    await transactions.load();
    final budgets = container.read(budgetListProvider.notifier);
    await budgets.add(BudgetModel(id: 'cafe', category: 'CAFÉ', limit: 100));
    await budgets.synchronize();
    await container.read(recurringListProvider.notifier).load();
    await transactions.add(TransactionModel(
        id: 'expense',
        type: 'expense',
        amount: 90,
        category: ' Café ',
        date: now));
    await transactions.add(TransactionModel(
        id: 'income',
        type: 'income',
        amount: 500,
        category: 'Café',
        date: now));
    await container.read(notificationPaymentsProvider.future);
    await container.pump();
    expect(container.read(categorySpentProvider).requireValue['café'], 90);
    expect(container.read(monthTotalsProvider).requireValue['expense'], 90);
    expect(container.read(serenoAlertsProvider).requireValue, hasLength(2));
    container.read(summaryPeriodTypeProvider.notifier).state =
        SummaryPeriodType.day;
    container.read(selectedMonthProvider.notifier).state =
        DateTime(now.year, now.month, now.day - 1);
    expect(container.read(monthTotalsProvider).requireValue['expense'], 0);
    expect(container.read(serenoAlertsProvider).requireValue, hasLength(2));
    await limit.save(200);
    await container.pump();
    expect(container.read(serenoAlertsProvider).requireValue.single.type,
        SerenoAlertType.budget);
    await budgets.add(BudgetModel(id: 'cafe', category: 'CAFÉ', limit: 200));
    await budgets.synchronize();
    await container.pump();
    expect(container.read(serenoAlertsProvider).requireValue, isEmpty);
    await limit.save(100);
    await transactions.remove('expense');
    await container.pump();
    expect(container.read(categorySpentProvider).requireValue, isEmpty);
    expect(container.read(serenoAlertsProvider).requireValue, isEmpty);
  });

  testWidgets(
      'central shows alerts and persists preference toggle on mobile width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      serenoAlertsProvider.overrideWithValue(const AsyncValue.data([
        SerenoAlert('test', SerenoAlertType.monthly,
            'Teto mensal perto do limite', '90% utilizado', 2)
      ])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Teto mensal perto do limite'), findsOneWidget);
    await tester.tap(find.text('Como funcionam os alertas'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('ao marcar uma conta como paga'), findsOneWidget);
    await tester.tap(find.text('Como funcionam os alertas'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(SwitchListTile, 'Teto mensal'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Teto mensal'));
    await tester.pumpAndSettle();
    expect((await NotificationPreferencesService(null).read()).monthly, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('failed alert sources show retry instead of an all-clear message',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      serenoAlertsProvider.overrideWithValue(
          AsyncValue.error(StateError('unavailable'), StackTrace.current))
    ], child: const MaterialApp(home: NotificationsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar todos os dados dos alertas.'),
        findsOneWidget);
    expect(
        find.text('Nenhum alerta ativo para suas preferências.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
