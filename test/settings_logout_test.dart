import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sereno_app/core/services/guest_service.dart';
import 'package:sereno_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:sereno_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';

class FakeLogout extends AuthController {
  FakeLogout(this.fail);
  final bool fail;
  int calls = 0;
  @override
  Future<void> signOut() async {
    calls++;
    if (fail) throw StateError('offline');
  }
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
        'account logout is visible and preserves records (failure: $fail)',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'preserved_record': 'financial data'});
      final auth = FakeLogout(fail);
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(const User(
            id: 'account',
            appMetadata: {},
            userMetadata: {'full_name': 'Pessoa'},
            aud: 'authenticated',
            createdAt: '2026-10-10T00:00:00Z')),
        transactionOwnerProvider.overrideWithValue(null),
        isGuestProvider.overrideWith((ref) => false),
        authControllerProvider.overrideWithValue(auth),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Trocar imagem'));
      await tester.pumpAndSettle();
      expect(find.text('Escolher imagem'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta'), findsOneWidget);
      expect(tester.getRect(find.text('Sair da conta')).bottom, lessThan(600));
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      expect(auth.calls, 1);
      expect(
          (await SharedPreferences.getInstance()).getString('preserved_record'),
          'financial data');
      if (fail) {
        expect(find.textContaining('Não foi possível sair da conta'),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
  }
}
