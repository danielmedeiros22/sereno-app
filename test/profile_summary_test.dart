import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/core/services/guest_service.dart';
import 'package:sereno_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:sereno_app/features/dashboard/data/monthly_limit_service.dart';
import 'package:sereno_app/features/dashboard/presentation/providers/monthly_limit_provider.dart';
import 'package:sereno_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:sereno_app/features/dashboard/presentation/widgets/profile_summary_card.dart';
import 'package:sereno_app/features/dashboard/presentation/widgets/segmented_limit_progress.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('month selection changes totals and count without mixing other months',
      () async {
    final service = TransactionSyncService();
    await service.save(TransactionModel(
        type: 'expense',
        amount: 10,
        category: 'Mercado',
        date: DateTime(2026, 9, 30)));
    await service.save(TransactionModel(
        type: 'expense',
        amount: 20,
        category: 'Mercado',
        date: DateTime(2026, 10, 1)));
    await service.save(TransactionModel(
        type: 'income',
        amount: 100,
        category: 'Salário',
        date: DateTime(2026, 10, 2)));
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
    ]);
    await container.read(transactionListProvider.notifier).load();
    expect(container.read(selectedMonthTransactionsProvider), hasLength(2));
    expect(container.read(monthTotalsProvider).valueOrNull?['expense'], 20);
    expect(container.read(monthTotalsProvider).valueOrNull?['balance'], 80);
    container.read(selectedMonthProvider.notifier).state = DateTime(2026, 9);
    expect(container.read(selectedMonthTransactionsProvider), hasLength(1));
    expect(container.read(monthTotalsProvider).valueOrNull?['expense'], 10);
    container.dispose();
  });
  testWidgets('segmented bar shows exact percentage including over budget',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SegmentedLimitProgress(percent: 64))));
    expect(find.text('64% do teto utilizado'), findsOneWidget);
    final bars = tester
        .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator))
        .toList();
    expect(bars, hasLength(10));
    expect(bars[5].value, 1);
    expect(bars[6].value, closeTo(0.4, 0.001));
    expect(bars[7].value, 0);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SegmentedLimitProgress(percent: 125))));
    expect(find.text('125% do teto utilizado'), findsOneWidget);
    expect(
        tester
            .widgetList<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .every((bar) => bar.value == 1),
        true);
  });

  testWidgets(
      'card and open limits sheet update together after spending and limit changes',
      (tester) async {
    await TransactionSyncService().save(TransactionModel(
        type: 'expense',
        amount: 2240,
        category: 'Mercado',
        date: DateTime(2026, 10, 10)));
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(null),
      isGuestProvider.overrideWith((ref) => true),
      transactionOwnerProvider.overrideWithValue(null),
      monthlyLimitOwnerProvider.overrideWithValue(null),
      monthlyLimitServiceProvider.overrideWithValue(MonthlyLimitService()),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen())));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('64% do teto utilizado'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver meus limites'));
    await tester.tap(find.text('Ver meus limites'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('64% do teto utilizado', skipOffstage: false),
        findsNWidgets(2));
    await container.read(monthlyLimitProvider.notifier).save(7000);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('32% do teto utilizado', skipOffstage: false),
        findsNWidgets(2));
    await container.read(transactionListProvider.notifier).add(TransactionModel(
        type: 'expense',
        amount: 1260,
        category: 'Mercado',
        date: DateTime(2026, 10, 11)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('50% do teto utilizado', skipOffstage: false),
        findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('photo options can be cancelled without changing the avatar',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          transactionOwnerProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: ProfileSummaryCard(percent: 0, onLimitsTap: () {})))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trocar imagem'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher imagem'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher imagem'), findsNothing);
  });
}
