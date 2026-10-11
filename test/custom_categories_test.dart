import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sereno_app/core/services/account_record_store.dart';
import 'package:sereno_app/features/budget/data/budget_model.dart';
import 'package:sereno_app/features/budget/data/local_budget_service.dart';
import 'package:sereno_app/features/budget/presentation/providers/budget_provider.dart';
import 'package:sereno_app/features/budget/presentation/screens/budget_form_screen.dart';
import 'package:sereno_app/features/recurring/data/local_recurring_service.dart';
import 'package:sereno_app/features/recurring/data/recurring_model.dart';
import 'package:sereno_app/features/recurring/presentation/screens/recurring_form_screen.dart';
import 'package:sereno_app/features/transactions/data/category_service.dart';
import 'package:sereno_app/features/transactions/data/default_categories.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:sereno_app/features/transactions/presentation/widgets/category_picker.dart';
import 'package:sereno_app/features/transactions/presentation/screens/transaction_form_screen.dart';

class CategoryCloud implements CategoryRemote {
  final rows = <String, Map<String, CategoryItem>>{};
  bool offline = false;
  @override
  Future<List<CategoryItem>> fetch(String owner) async {
    if (offline) throw StateError('offline');
    return (rows[owner] ?? {}).values.toList();
  }

  @override
  Future<void> save(String owner, CategoryItem item) async {
    if (offline) throw StateError('offline');
    rows.putIfAbsent(owner, () => {})[item.key] = item;
  }
}

class RecordCloud implements AccountRecordRemote {
  final rows = <String, Map<String, Map<String, dynamic>>>{};
  bool offline = false;
  Completer<void>? pause;
  Completer<void>? started;
  @override
  Future<void> save(
      String owner, String kind, Map<String, dynamic> entry) async {
    if (offline) throw StateError('offline');
    started?.complete();
    final wait = pause;
    pause = null;
    started = null;
    if (wait != null) await wait.future;
    rows.putIfAbsent('$owner:$kind', () => {})[entry['id'] as String] =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(entry)) as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String owner, String kind) async {
    if (offline) throw StateError('offline');
    return (rows['$owner:$kind'] ?? {}).values.toList();
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'offline financial records persist through restart without adopting guest data',
      () async {
    final cloud = RecordCloud()..offline = true;
    final guest = LocalBudgetService();
    await guest.add(BudgetModel(category: 'Mercado', limit: 999));
    final account = LocalBudgetService(owner: 'a', remote: cloud);
    expect(await account.getAll(), isEmpty);
    await account
        .add(BudgetModel(category: 'Café', categoryIcon: '☕', limit: 50));
    await expectLater(account.synchronize(), throwsStateError);
    final reboot = LocalBudgetService(owner: 'a', remote: cloud);
    expect((await reboot.getAll()).single.limit, 50);
    expect(await reboot.store.pendingCount(), 1);
    cloud.offline = false;
    await reboot.synchronize();
    SharedPreferences.setMockInitialValues({});
    final device = LocalBudgetService(owner: 'a', remote: cloud);
    await device.synchronize();
    expect((await device.getAll()).single.categoryIcon, '☕');
    expect(await device.store.pendingCount(), 0);
  });

  test('custom category and emoji survive transaction persistence unchanged',
      () async {
    final service = TransactionSyncService(userId: 'a');
    await service.save(TransactionModel(
        type: 'expense',
        amount: 1,
        category: 'Família',
        categoryIcon: '👨‍👩‍👧‍👦',
        date: DateTime.now()));
    final restored =
        (await TransactionSyncService(userId: 'a').getAll()).single;
    expect(restored.category, 'Família');
    expect(restored.categoryIcon, '👨‍👩‍👧‍👦');
  });

  test(
      'preserves complete emoji graphemes and rejects empty, multiple or text icons',
      () {
    for (final emoji in ['👨‍👩‍👧‍👦', '👍🏽', '🇧🇷', '1️⃣', '☕', '🏷️']) {
      expect(CategoryService.validate('Viagem', emoji, 'expense').icon, emoji);
    }
    for (final emoji in ['', 'abc', '☕☕', 'a☕']) {
      expect(() => CategoryService.validate('Viagem', emoji, 'expense'),
          throwsArgumentError);
    }
    expect(() => CategoryService.validate(' ', '☕', 'expense'),
        throwsArgumentError);
  });

  test('normalizes names and blocks duplicates without changing the catalog',
      () async {
    final service = CategoryService();
    await service.add('  Café   especial ', '☕', 'expense');
    expect((await service.getAll()).single.name, 'Café especial');
    await expectLater(
        service.add('CAFÉ ESPECIAL', '🌱', 'expense'), throwsArgumentError);
    await expectLater(
        service.add('mercado', '🌱', 'expense'), throwsArgumentError);
    await service.add('Café especial', '☕', 'income');
    expect(await service.getAll(), hasLength(2));
  });

  test(
      'category survives offline restart and appears in clean device of same account only',
      () async {
    final cloud = CategoryCloud()..offline = true;
    final a = CategoryService(owner: 'a', remote: cloud);
    await a.add('Família', '👨‍👩‍👧‍👦', 'expense');
    await expectLater(a.synchronize(), throwsStateError);
    final reboot = CategoryService(owner: 'a', remote: cloud);
    expect(await reboot.pendingCount(), 1);
    cloud.offline = false;
    await reboot.synchronize();
    expect(await reboot.pendingCount(), 0);
    SharedPreferences.setMockInitialValues({});
    final device = CategoryService(owner: 'a', remote: cloud);
    await device.synchronize();
    expect((await device.getAll()).single.icon, '👨‍👩‍👧‍👦');
    final other = CategoryService(owner: 'b', remote: cloud);
    await other.synchronize();
    expect(await other.getAll(), isEmpty);
    expect(await CategoryService().getAll(), isEmpty);
  });

  test(
      'budgets and recurring payments sync to clean device and deletions do not resurrect',
      () async {
    final cloud = RecordCloud();
    final budgets = LocalBudgetService(owner: 'a', remote: cloud);
    await budgets
        .add(BudgetModel(category: 'Café', categoryIcon: '☕', limit: 50));
    await budgets
        .add(BudgetModel(category: 'Café', categoryIcon: '☕', limit: 100));
    await budgets.synchronize();
    expect(await budgets.getAll(), hasLength(1));
    final rules = LocalRecurringService(owner: 'a', remote: cloud);
    final rule = RecurringModel(
        name: 'Assinatura',
        amount: 10,
        category: 'Café',
        categoryIcon: '☕',
        frequency: RecurringFrequency.monthly,
        dueDay: 10);
    await rules.add(rule);
    await rules.markPaid(rule.id, '2026-10');
    await rules.synchronize();
    SharedPreferences.setMockInitialValues({});
    final newBudget = LocalBudgetService(owner: 'a', remote: cloud);
    final newRules = LocalRecurringService(owner: 'a', remote: cloud);
    await newBudget.synchronize();
    await newRules.synchronize();
    expect((await newBudget.getAll()).single.limit, 100);
    expect((await newBudget.getAll()).single.categoryIcon, '☕');
    expect((await newRules.getAll()).single.categoryIcon, '☕');
    expect(await newRules.isPaid(rule.id, '2026-10'), true);
    await newRules.unmarkPaid(rule.id, '2026-10');
    await newRules.delete(rule.id);
    await newBudget.delete((await newBudget.getAll()).single.id);
    await newRules.synchronize();
    await newBudget.synchronize();
    SharedPreferences.setMockInitialValues({});
    await rules.synchronize();
    await budgets.synchronize();
    expect(await rules.getAll(), isEmpty);
    expect(await rules.isPaid(rule.id, '2026-10'), false);
    expect(await budgets.getAll(), isEmpty);
    final other = LocalBudgetService(owner: 'b', remote: cloud);
    await other.synchronize();
    expect(await other.getAll(), isEmpty);
  });

  test(
      'record outbox retains edits during upload and reviewed deletion preserves changed records',
      () async {
    final cloud = RecordCloud();
    final store = AccountRecordStore(
        kind: 'budget', guestKey: 'test', owner: 'a', remote: cloud);
    await store.save({'id': 'one', 'limit': 10});
    final gate = Completer<void>();
    final started = Completer<void>();
    cloud.pause = gate;
    cloud.started = started;
    final sync = store.synchronize();
    await started.future;
    await store.save({'id': 'one', 'limit': 50});
    gate.complete();
    await sync;
    expect((await store.getAll()).single['limit'], 50);
    expect(await store.pendingCount(), 1);
    await store.synchronize();
    expect(await store.pendingCount(), 0);
    expect(
        await store.deleteReviewed([
          {'id': 'one', 'limit': 10}
        ]),
        0);
    expect(
        await store.deleteReviewed([
          {'limit': 50, 'id': 'one'}
        ]),
        1);
    await store.synchronize();
    expect(await store.getAll(), isEmpty);
  });

  test('guest recurring payments and legacy data stay isolated from account',
      () async {
    SharedPreferences.setMockInitialValues({
      'recurring_paid': jsonEncode({
        '2026-10': ['old']
      })
    });
    final guest = LocalRecurringService();
    expect(await guest.isPaid('old', '2026-10'), true);
    await guest.unmarkPaid('old', '2026-10');
    expect(await guest.isPaid('old', '2026-10'), false);
    expect((await guest.legacyPayments()).single['paid'], false);
    expect(await LocalRecurringService(owner: 'a').isPaid('old', '2026-10'),
        false);
  });

  test('budget spending uses account transaction provider, not guest storage',
      () async {
    await TransactionSyncService().save(TransactionModel(
        type: 'expense', amount: 999, category: 'Café', date: DateTime.now()));
    final account = TransactionSyncService(userId: 'a');
    await account.save(TransactionModel(
        type: 'expense',
        amount: 12,
        category: 'Café',
        categoryIcon: '☕',
        date: DateTime.now()));
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      localTransactionServiceProvider.overrideWithValue(account),
    ]);
    await container.read(transactionListProvider.notifier).load();
    expect(container.read(categorySpentProvider).valueOrNull?['Café'], 12);
    container.dispose();
  });

  testWidgets(
      'custom category creation appears in all three pickers and cancel saves nothing',
      (tester) async {
    final container = ProviderContainer(
        overrides: [transactionOwnerProvider.overrideWithValue(null)]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BudgetFormScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar categoria'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.labelText == 'Nome da categoria'),
        'Café especial');
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Emoji'),
        '☕');
    await tester.tap(find.text('Criar categoria'));
    await tester.pumpAndSettle();
    expect(find.text('☕  Café especial'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, '☕  Café especial'))
            .selected,
        true);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecurringFormScreen())));
    await tester.pumpAndSettle();
    expect(find.text('☕  Café especial'), findsOneWidget);
    await tester.ensureVisible(find.text('Adicionar categoria'));
    await tester.tap(find.text('Adicionar categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await CategoryService().getAll(), hasLength(1));
    expect(find.byType(CategoryPicker), findsOneWidget);
    const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(locationChannel, (call) async => 0);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(locationChannel, null));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TransactionFormScreen())));
    await tester.pumpAndSettle();
    expect(find.text('☕  Café especial'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
