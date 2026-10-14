import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/core/services/financial_record_sync_provider.dart';
import 'package:sereno_app/features/transactions/data/transaction_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sereno_app/core/services/guest_service.dart';
import 'package:sereno_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:sereno_app/features/auth/presentation/providers/profile_name_provider.dart';
import 'package:sereno_app/features/dashboard/data/avatar_service.dart';
import 'package:sereno_app/features/dashboard/presentation/providers/avatar_provider.dart';
import 'package:sereno_app/features/dashboard/presentation/widgets/profile_summary_card.dart';
import 'package:sereno_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';

User account([String? name, String id = 'account']) => User(
    id: id,
    email: 'person@example.com',
    appMetadata: {},
    userMetadata: {
      'full_name': 'Nome Google',
      if (name != null) 'sereno_display_name': name
    },
    aud: 'authenticated',
    createdAt: '2026-10-10T00:00:00Z');

class ProfileAuth extends AuthController {
  User user = account();
  bool fail = false;
  int writes = 0;
  Completer<User?>? pendingRead;
  @override
  Future<User?> readProfile() async =>
      pendingRead == null ? user : pendingRead!.future;
  @override
  Future<User?> updateDisplayName(String owner, String name) async {
    if (fail) throw StateError('offline');
    writes++;
    user = account(name, owner);
    return user;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('saved name reaches another device and preserves email and Google name',
      () async {
    final auth = ProfileAuth();
    final first = ProfileNameNotifier('account', 'Nome Google', auth);
    final second = ProfileNameNotifier('account', 'Nome Google', auth);
    await first.save('  Meu nome  ');
    await second.synchronize();
    expect(first.state, 'Meu nome');
    expect(second.state, 'Meu nome');
    expect(auth.user.email, 'person@example.com');
    expect(auth.user.userMetadata!['full_name'], 'Nome Google');
    expect(auth.writes, 1);
    final reopened = ProfileNameNotifier('account', 'Nome Google', auth);
    await reopened.synchronize();
    expect(reopened.state, 'Meu nome');
    first.dispose();
    second.dispose();
    reopened.dispose();
  });

  test('failed save and invalid names preserve previous name', () async {
    final auth = ProfileAuth();
    final notifier = ProfileNameNotifier('account', 'Nome Google', auth);
    await notifier.synchronize();
    for (final invalid in ['   ', List.filled(81, 'a').join()]) {
      await expectLater(notifier.save(invalid), throwsArgumentError);
    }
    auth.fail = true;
    await expectLater(notifier.save('Novo'), throwsStateError);
    expect(notifier.state, 'Nome Google');
    expect(auth.writes, 0);
    notifier.dispose();
  });

  test('late reads from another identity cannot change displayed name',
      () async {
    final auth = ProfileAuth()..user = account('Outra pessoa', 'other');
    final notifier = ProfileNameNotifier('account', 'Nome Google', auth);
    await notifier.synchronize();
    expect(notifier.state, 'Nome Google');
    notifier.dispose();
  });

  test('leaving the account during a pending read prevents a queued save',
      () async {
    final auth = ProfileAuth()..pendingRead = Completer<User?>();
    final notifier = ProfileNameNotifier('account', 'Nome Google', auth);
    final save = notifier.save('Novo nome');
    final result = expectLater(save, throwsStateError);
    notifier.dispose();
    auth.pendingRead!.complete(account('Nome remoto'));
    await result;
    expect(auth.writes, 0);
  });

  for (final fail in [false, true]) {
    testWidgets('both profile cards edit the same name (failure: $fail)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = ProfileAuth()..fail = fail;
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(auth.user),
        authControllerProvider.overrideWithValue(auth),
        transactionOwnerProvider.overrideWithValue('account'),
        financialRecordRemoteProvider.overrideWithValue(null),
        localTransactionServiceProvider
            .overrideWithValue(TransactionSyncService(userId: 'account')),
        selectedMonthTransactionsProvider.overrideWithValue([]),
        avatarServiceProvider.overrideWithValue(AvatarService(owner: null)),
        isGuestProvider.overrideWith((ref) => false),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              home: Row(children: [
            const Expanded(child: SettingsScreen()),
            Expanded(
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: ProfileSummaryCard(
                            percent: 0, onLimitsTap: () {})))),
          ]))));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Editar nome'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Editar nome').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Rascunho');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(auth.writes, 0);
      await tester.tap(find.byTooltip('Editar nome').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe seu nome.'), findsOneWidget);
      expect(auth.writes, 0);
      await tester.enterText(find.byType(TextFormField), 'Meu nome');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      if (fail) {
        expect(find.textContaining('Não foi possível salvar.'), findsOneWidget);
        expect(find.text('Nome Google'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Meu nome'), findsOneWidget);
        expect(find.text('Meu nome · Todos os espaços'), findsOneWidget);
      }
      expect(find.text('person@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
  }
}
