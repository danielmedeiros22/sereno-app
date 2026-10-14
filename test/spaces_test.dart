import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/core/services/financial_record_sync_provider.dart';
import 'package:sereno_app/features/reports/report_data.dart';
import 'package:sereno_app/core/services/guest_service.dart';
import 'package:sereno_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:sereno_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:sereno_app/features/spaces/spaces_provider.dart';
import 'package:sereno_app/features/spaces/spaces_screen.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:sereno_app/features/transactions/presentation/screens/transaction_form_screen.dart';
import 'custom_categories_test.dart' show RecordCloud;
import 'transaction_sync_service_test.dart' show MemoryRemote;

TransactionModel _tx(double amount) => TransactionModel(
    type: 'expense',
    amount: amount,
    category: 'Mercado',
    date: DateTime(2026, 10, 14),
    description: 'preservar',
    latitude: -23,
    longitude: -46,
    location: 'Endereço');

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy records default to Pessoal and moving preserves financial data',
      () {
    final old = _tx(70).toJson()
      ..remove('spaceId')
      ..remove('spaceName');
    final tx = TransactionModel.fromJson(old);
    expect(tx.spaceId, 'personal');
    final moved = tx.inSpace('home', 'Casa').toJson()
      ..remove('spaceId')
      ..remove('spaceName');
    expect(moved, old);
    expect(
        TransactionModel.fromJson(tx.inSpace('home', 'Casa').toJson()).spaceId,
        'home');
  });

  test('spaces sync offline, rename with stable ID and isolate owner and guest',
      () async {
    final cloud = RecordCloud();
    final first = SpaceService(owner: 'a', remote: cloud);
    expect(await first.getAll(), hasLength(4));
    cloud.offline = true;
    final created = await first.save('Projeto', '🧑🏽‍🍳');
    await expectLater(first.store.synchronize(), throwsStateError);
    expect(await first.store.pendingCount(), 1);
    cloud.offline = false;
    await first.store.synchronize();
    SharedPreferences.setMockInitialValues({});
    final otherDevice = SpaceService(owner: 'a', remote: cloud);
    await otherDevice.store.synchronize();
    expect((await otherDevice.getAll()).last.id, created.id);
    await otherDevice.save('Novo projeto', '🏠', id: created.id);
    await otherDevice.store.synchronize();
    await first.store.synchronize();
    expect((await first.getAll()).last.name, 'Novo projeto');
    expect((await first.getAll()).last.id, created.id);
    final otherAccount = SpaceService(owner: 'b', remote: cloud);
    await otherAccount.store.synchronize();
    expect(await otherAccount.getAll(), hasLength(4));
    await SpaceService().save('Só visitante', '📁');
    expect(await otherAccount.getAll(), hasLength(4));
    await expectLater(first.save('pessoal', '🏠'), throwsStateError);
    await expectLater(first.save('X', '🏠', id: 'personal'), throwsStateError);
  });

  test(
      'transaction cloud transport preserves space on receive, move and delete',
      () async {
    final cloud = MemoryRemote();
    final first = TransactionSyncService(userId: 'a', remote: cloud);
    final tx = _tx(25).inSpace('home', 'Casa');
    await first.save(tx);
    await first.synchronize();
    SharedPreferences.setMockInitialValues({});
    final second = TransactionSyncService(userId: 'a', remote: cloud);
    await second.synchronize();
    expect((await second.getAll()).single.spaceId, 'home');
    await second.save(tx.inSpace('travel', 'Viagem'));
    await second.synchronize();
    await first.synchronize();
    expect((await first.getAll()).single.spaceId, 'travel');
    await first.delete(tx.id);
    await first.synchronize();
    await second.synchronize();
    expect(await second.getAll(), isEmpty);
  });

  test(
      'shared filter keeps reports and dashboard aligned; account limit totals remain global',
      () async {
    final owner = StateProvider<String?>((ref) => null);
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWith((ref) => ref.watch(owner)),
      financialRecordRemoteProvider.overrideWithValue(null),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10, 14)),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(transactionListProvider.notifier);
    await notifier.load();
    await notifier.add(_tx(70));
    await notifier.add(_tx(20).inSpace('home', 'Casa'));
    container.read(selectedSpaceProvider.notifier).state = 'home';
    expect(container.read(monthTotalsProvider).valueOrNull!['expense'], 20);
    expect(container.read(reportProvider).valueOrNull!.expense, 2000);
    expect(container.read(selectedMonthTransactionsProvider), hasLength(1));
    expect(container.read(accountPeriodTotalsProvider).valueOrNull!['expense'],
        90);
    container.read(owner.notifier).state = 'another';
    expect(container.read(selectedSpaceProvider), isNull);
  });

  testWidgets('space creation, cancellation and editing use the same catalog',
      (tester) async {
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      financialRecordRemoteProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: SpacesScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo espaço'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Projeto');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await container.read(spaceServiceProvider).getAll(), hasLength(4));
    await tester.tap(find.text('Novo espaço'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Projeto');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Projeto'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar Projeto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Projeto novo');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Projeto novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new transaction records the selected space', (tester) async {
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 0);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
      financialRecordRemoteProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    container.read(selectedSpaceProvider.notifier).state = 'home';
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => const TransactionFormScreen())),
                        child: const Text('Abrir')))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('🏠 Casa'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '25,00');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final records =
        await container.read(localTransactionServiceProvider).getAll();
    expect(records.single.spaceId, 'home');
    expect(records.single.amount, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'moving an existing transaction requires confirmation and preserves its amount',
      (tester) async {
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(null),
      isGuestProvider.overrideWith((ref) => true),
      transactionOwnerProvider.overrideWithValue(null),
      financialRecordRemoteProvider.overrideWithValue(null),
      selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10, 14)),
    ]);
    final notifier = container.read(transactionListProvider.notifier);
    await notifier.load();
    final record = _tx(25);
    await notifier.add(record);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen())));
    // The orb has a continuous animation, so use bounded frames.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.scrollUntilVisible(find.text('Mercado'), 200);
    await tester.tap(find.text('Mercado'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        (await container.read(localTransactionServiceProvider).getAll())
            .single
            .spaceId,
        'personal');
    await tester.tap(find.text('Mercado'));
    await tester.pump(const Duration(milliseconds: 400));
    final dropdown = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>));
    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('🏠 Casa').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Confirmar'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final moved =
        (await container.read(localTransactionServiceProvider).getAll()).single;
    expect(moved.spaceId, 'home');
    expect(moved.amount, record.amount);
    expect(moved.id, record.id);
    expect(moved.latitude, record.latitude);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
