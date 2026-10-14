import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sereno_app/app/theme/app_page_transitions.dart';

void main() {
  test('native iOS and other Web platforms preserve default transitions', () {
    const defaults = PageTransitionsTheme();
    expect(appPageTransitions(isWeb: false).builders[TargetPlatform.iOS],
        same(defaults.builders[TargetPlatform.iOS]));
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux
    ]) {
      expect(appPageTransitions(isWeb: true).builders[platform],
          same(defaults.builders[platform]));
    }
  });

  testWidgets('iOS Web push and pop do not apply a second lateral transition',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData(
          platform: TargetPlatform.iOS,
          pageTransitionsTheme: appPageTransitions(isWeb: true)),
      home: const Scaffold(body: Text('Ajustes')),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Notificações'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SlideTransition), findsNothing);
    expect(tester.getTopLeft(find.text('Notificações')).dx, 0);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SlideTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Notificações'), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
  });
}
