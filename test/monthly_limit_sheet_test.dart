import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/dashboard/data/monthly_limit_service.dart';
import 'package:sereno_app/features/dashboard/presentation/providers/monthly_limit_provider.dart';
import 'package:sereno_app/features/dashboard/presentation/widgets/monthly_limit_sheet.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
      WidgetTester tester, Future<void> Function(double) save) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        monthlyLimitOwnerProvider.overrideWithValue(null),
        monthlyLimitServiceProvider.overrideWithValue(MonthlyLimitService()),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: MonthlyLimitSheet(
            currentLimit: 3500,
            currentSpent: 100,
            owner: null,
            onChanged: save),
      ))),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('digitar e cancelar não salvam; confirmar salva uma vez',
      (tester) async {
    final saved = <double>[];
    await open(tester, (value) async => saved.add(value));
    await tester.enterText(find.byType(TextField), '6200,50');
    await tester.pump();
    expect(saved, isEmpty);
    await tester.tap(find.text('Salvar alteração'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Novo teto:'), findsOneWidget);
    expect(saved, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(saved, isEmpty);
    await tester.tap(find.text('Salvar alteração'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(saved, [6200.5]);
    expect(find.text('Teto mensal salvo.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'erro de gravação mantém alteração disponível para tentar novamente',
      (tester) async {
    await open(tester, (_) async => throw StateError('offline storage'));
    await tester.enterText(find.byType(TextField), '6000');
    await tester.pump();
    await tester.tap(find.text('Salvar alteração'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Salvar alteração'))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final value in [1.0, 50.0]) {
    testWidgets('confirma teto de R\$ $value', (tester) async {
      final saved = <double>[];
      await open(tester, (amount) async => saved.add(amount));
      await tester.enterText(find.byType(TextField), value.toString());
      await tester.pump();
      await tester.tap(find.text('Salvar alteração'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(saved, isEmpty);
      await tester.tap(find.text('Confirmar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(saved, [value]);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
