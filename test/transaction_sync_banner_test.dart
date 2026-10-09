import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:sereno_app/features/transactions/presentation/widgets/transaction_sync_banner.dart';

Future<ProviderContainer> openBanner(WidgetTester tester) async {
  final container = ProviderContainer(overrides: [
    transactionOwnerProvider.overrideWithValue('account-a'),
    localTransactionServiceProvider
        .overrideWithValue(TransactionSyncService(userId: 'account-a')),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: TransactionSyncBanner()))));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    final legacy = TransactionModel(
        type: 'expense',
        amount: 50,
        category: 'Mercado',
        date: DateTime(2026, 10, 9));
    SharedPreferences.setMockInitialValues({
      'local_transactions': jsonEncode([legacy.toJson()])
    });
  });

  testWidgets('canceling legacy import never assigns records to the account',
      (tester) async {
    final container = await openBanner(tester);
    await tester.tap(find.text('Importar 1 lançamentos locais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await container.read(localTransactionServiceProvider).getAll(),
        isEmpty);
    expect(await TransactionSyncService().getAll(), hasLength(1));
  });

  testWidgets(
      'only confirmation imports legacy records and removes import button',
      (tester) async {
    final container = await openBanner(tester);
    await tester.tap(find.text('Importar 1 lançamentos locais'));
    await tester.pumpAndSettle();
    expect(await container.read(localTransactionServiceProvider).getAll(),
        isEmpty);
    await tester.tap(find.text('Importar', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(await container.read(localTransactionServiceProvider).getAll(),
        hasLength(1));
    expect(await TransactionSyncService().getAll(), hasLength(1));
    expect(find.text('Importar 1 lançamentos locais'), findsNothing);
  });
}
