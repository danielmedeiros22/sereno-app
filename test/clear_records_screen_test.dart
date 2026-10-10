import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/settings/presentation/screens/clear_records_screen.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester) async {
    await TransactionSyncService().save(TransactionModel(
        type: 'income', amount: 20, category: 'Salário', date: DateTime.now()));
    await tester.pumpWidget(ProviderScope(overrides: [
      transactionOwnerProvider.overrideWithValue(null),
    ], child: const MaterialApp(home: ClearRecordsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entradas'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Revisar exclusão'), 200);
    await tester.tap(find.text('Revisar exclusão'));
    await tester.pumpAndSettle();
  }

  testWidgets('review and cancel do not delete anything', (tester) async {
    await open(tester);
    expect(find.textContaining('Total: 1 registros.'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await TransactionSyncService().getAll(), hasLength(1));
  });

  testWidgets('requires both authorization and exact confirmation text',
      (tester) async {
    await open(tester);
    FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Excluir registros'));
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'EXCLUIR');
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull);
    await tester.tap(find.text('Autorizo a exclusão dos registros acima.'));
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
    await tester.tap(find.text('Excluir registros'));
    await tester.pumpAndSettle();
    expect(await TransactionSyncService().getAll(), isEmpty);
  });
}
