import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/app/app.dart';
import 'package:sereno_app/app/router/app_router.dart';

void main() {
  testWidgets('app date picker uses Portuguese even on an English device',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
              body: TextButton(
                  onPressed: () => showDatePicker(
                      context: context,
                      initialDate: DateTime(2026, 10, 10),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030)),
                  child: const Text('Abrir calendário'))))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      routerProvider.overrideWithValue(router),
    ], child: const SerenoApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir calendário'));
    await tester.pumpAndSettle();
    final pickerContext = tester.element(find.byType(DatePickerDialog));
    expect(Localizations.localeOf(pickerContext), const Locale('pt', 'BR'));
    expect(find.textContaining('outubro'), findsWidgets);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Select date'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });
}
