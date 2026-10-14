import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';
import 'package:sereno_app/features/reports/report_data.dart';
import 'package:sereno_app/features/reports/reports_screen.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/presentation/providers/summary_period.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';

TransactionModel tx(double amount, DateTime date,
        {String category = 'Mercado', String type = 'expense'}) =>
    TransactionModel(
        amount: amount,
        date: date,
        category: category,
        categoryIcon: '🧑🏽‍🍳',
        type: type);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  test('real report provider follows edits, deletion and account isolation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final owner = StateProvider<String?>((ref) => 'account-a');
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWith((ref) => ref.watch(owner)),
      localTransactionServiceProvider.overrideWith((ref) =>
          TransactionSyncService(userId: ref.watch(transactionOwnerProvider))),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10, 14)),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(transactionListProvider.notifier);
    await notifier.load();
    final record = tx(50, DateTime(2026, 10, 14));
    await notifier.add(record);
    expect(container.read(reportProvider).valueOrNull!.expense, 5000);
    expect(container.read(monthTotalsProvider).valueOrNull!['expense'], 50);
    await notifier.update(TransactionModel(
        id: record.id,
        type: 'expense',
        amount: 75,
        category: 'Outra',
        date: record.date));
    expect(container.read(reportProvider).valueOrNull!.expense, 7500);
    expect(container.read(reportProvider).valueOrNull!.categories.single.name,
        'Outra');
    container.read(owner.notifier).state = 'account-b';
    await container.read(transactionListProvider.notifier).load();
    expect(container.read(reportProvider).valueOrNull!.count, 0);
    container.read(owner.notifier).state = 'account-a';
    final restored = container.read(transactionListProvider.notifier);
    await restored.load();
    expect(container.read(reportProvider).valueOrNull!.expense, 7500);
    await restored.remove(record.id);
    expect(container.read(reportProvider).valueOrNull!.count, 0);
  });
  test(
      'period boundaries, custom category grouping and cents agree with totals',
      () {
    final period = SummaryPeriod(SummaryPeriodType.week, DateTime(2027, 1, 1));
    final data = ReportData.fromRecords([
      tx(0.1, DateTime(2026, 12, 28), category: ' Minha categoria '),
      tx(0.2, DateTime(2027, 1, 3, 23, 59), category: 'minha   categoria'),
      tx(100, DateTime(2027, 1, 1), type: 'income'),
      tx(500, DateTime(2027, 1, 4)),
      tx(500, DateTime(2026, 12, 27)),
    ], period);
    expect(data.count, 3);
    expect(data.expense, 30);
    expect(data.income, 10000);
    expect(data.categories.single.cents, 30);
    expect(data.categories.single.icon, '🧑🏽‍🍳');
    expect(data.buckets, [10, 0, 0, 0, 0, 0, 20]);
    expect(data.buckets.reduce((a, b) => a + b), data.expense);
  });

  test('leap month and hourly buckets include last instant and empty periods',
      () {
    final month = SummaryPeriod(SummaryPeriodType.month, DateTime(2028, 2, 4));
    final data = ReportData.fromRecords([
      tx(75, DateTime(2028, 2, 29, 23, 59)),
      tx(100, DateTime(2028, 3, 1)),
    ], month);
    expect(data.buckets.length, 29);
    expect(data.buckets.last, 7500);
    final day = ReportData.fromRecords([
      tx(25, DateTime(2028, 2, 29, 0)),
      tx(50, DateTime(2028, 2, 29, 23)),
    ], SummaryPeriod(SummaryPeriodType.day, DateTime(2028, 2, 29)));
    expect(day.buckets.length, 24);
    expect(day.buckets.first, 2500);
    expect(day.buckets.last, 5000);
    final empty = ReportData.fromRecords([], month);
    expect(empty.expense, 0);
    expect(empty.categories, isEmpty);
  });

  testWidgets(
      'mobile reports react to edits and shared period without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = StateProvider<List<TransactionModel>>((ref) => [
          tx(50, DateTime(2026, 10, 14)),
          tx(100, DateTime(2026, 10, 15)),
        ]);
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10, 14)),
      reportProvider.overrideWith((ref) => AsyncValue.data(
          ReportData.fromRecords(
              ref.watch(source), ref.watch(summaryPeriodProvider)))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: ReportsScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('2 lançamentos no período'), 150);
    expect(find.text('2 lançamentos no período'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dia'));
    await tester.pumpAndSettle();
    expect(container.read(summaryPeriodProvider).type, SummaryPeriodType.day);
    await tester.scrollUntilVisible(find.text('1 lançamento no período'), 150);
    expect(find.text('1 lançamento no período'), findsOneWidget);
    container.read(source.notifier).state = [];
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Nenhum lançamento neste período'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
