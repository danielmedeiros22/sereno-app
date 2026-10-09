import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/dashboard/data/monthly_limit_service.dart';
import 'package:sereno_app/features/dashboard/presentation/providers/monthly_limit_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restaura o teto salvo em uma nova instância', () async {
    expect(await MonthlyLimitService().load(), 3500);
    await MonthlyLimitService().save(6200);
    expect(await MonthlyLimitService().load(), 6200);
  });

  test('valor inválido não substitui o teto salvo', () async {
    final service = MonthlyLimitService();
    await service.save(5000);
    await expectLater(service.save(double.nan), throwsArgumentError);
    await expectLater(service.save(99), throwsArgumentError);
    expect(await service.load(), 5000);
  });

  test('visitante e contas diferentes não compartilham o teto', () async {
    final guest = MonthlyLimitService();
    final a = MonthlyLimitService(userId: 'a');
    final b = MonthlyLimitService(userId: 'b');
    await guest.save(4200);
    await a.save(8000);
    expect(await guest.load(), 4200);
    expect(await a.load(), 8000);
    expect(await b.load(), 3500);
  });

  test('chave antiga só é restaurada para visitante', () async {
    SharedPreferences.setMockInitialValues({'monthly_spending_limit': 7100.0});
    expect(await MonthlyLimitService().load(), 7100);
    expect(await MonthlyLimitService(userId: 'a').load(), 3500);
  });

  test('alteração offline sobrevive a reinício e sincroniza depois', () async {
    final remote = FakeRemote()..offline = true;
    final service = MonthlyLimitService(userId: 'a', remote: remote);
    await service.save(6500);
    await expectLater(service.synchronize(), throwsStateError);
    final reopened = MonthlyLimitService(userId: 'a', remote: remote);
    expect((await reopened.read()).pending, isTrue);
    remote.offline = false;
    expect((await reopened.synchronize()).pending, isFalse);
    expect(remote.values['a'], 6500);
  });

  test('novo dispositivo busca o teto da mesma conta sem enviar o padrão',
      () async {
    final remote = FakeRemote();
    final first = MonthlyLimitService(userId: 'a', remote: remote);
    await first.save(6200);
    await first.synchronize();
    SharedPreferences.setMockInitialValues({});
    final second = MonthlyLimitService(userId: 'a', remote: remote);
    expect((await second.synchronize()).value, 6200);
    expect(remote.writes, 1);
  });

  test('conta sem teto remoto não grava automaticamente R\$ 3500', () async {
    final remote = FakeRemote();
    final service = MonthlyLimitService(userId: 'a', remote: remote);
    expect((await service.synchronize()).value, 3500);
    expect(remote.writes, 0);
  });

  test('resposta de leitura atrasada não apaga edição local', () async {
    final gate = Completer<double?>();
    final remote = FakeRemote()..fetchGate = gate;
    final service = MonthlyLimitService(userId: 'a', remote: remote);
    final sync = service.synchronize();
    await remote.started.future;
    await service.save(9000);
    gate.complete(4000);
    final result = await sync;
    expect(result.value, 9000);
    expect(result.pending, isTrue);
  });

  test('confirmação de envio não limpa uma edição posterior', () async {
    final gate = Completer<void>();
    final remote = FakeRemote()..saveGate = gate;
    final service = MonthlyLimitService(userId: 'a', remote: remote);
    await service.save(5000);
    final sync = service.synchronize();
    await remote.started.future;
    await service.save(7000);
    gate.complete();
    final result = await sync;
    expect(result.value, 7000);
    expect(result.pending, isTrue);
    remote.saveGate = null;
    await service.synchronize();
    expect(remote.values['a'], 7000);
  });

  test('visitante nunca acessa a nuvem', () async {
    final remote = FakeRemote();
    final service = MonthlyLimitService(remote: remote);
    await service.save(4800);
    expect((await service.synchronize()).value, 4800);
    expect(remote.started.isCompleted, isFalse);
  });

  test('conflito entre dispositivos usa o último envio aceito', () async {
    final remote = FakeRemote()..values['a'] = 9000;
    final service = MonthlyLimitService(userId: 'a', remote: remote);
    await service.save(6000);
    await service.synchronize();
    expect(remote.values['a'], 6000);
    remote.values['a'] = 10000;
    expect((await service.synchronize()).value, 10000);
  });

  test('sincronizações simultâneas não duplicam um envio', () async {
    final gate = Completer<void>();
    final remote = FakeRemote()..saveGate = gate;
    final service = MonthlyLimitService(userId: 'a', remote: remote);
    await service.save(6000);
    final first = service.synchronize();
    final second = service.synchronize();
    gate.complete();
    await Future.wait([first, second]);
    expect(remote.writes, 1);
  });

  test('trocar de conta recria a tela sem expor o teto anterior', () async {
    final owner = StateProvider<String?>((ref) => 'a');
    final container = ProviderContainer(overrides: [
      monthlyLimitOwnerProvider.overrideWith((ref) => ref.watch(owner)),
      monthlyLimitServiceProvider.overrideWith((ref) =>
          MonthlyLimitService(userId: ref.watch(monthlyLimitOwnerProvider))),
    ]);
    addTearDown(container.dispose);
    final listener = container.listen(monthlyLimitProvider, (_, __) {});
    addTearDown(listener.close);
    await container.read(monthlyLimitProvider.notifier).ready;
    await container.read(monthlyLimitProvider.notifier).save(8500);
    container.read(owner.notifier).state = 'b';
    await container.pump();
    await container.read(monthlyLimitProvider.notifier).ready;
    expect(container.read(monthlyLimitProvider).value!.record.value, 3500);
    container.read(owner.notifier).state = 'a';
    await container.pump();
    await container.read(monthlyLimitProvider.notifier).ready;
    expect(container.read(monthlyLimitProvider).value!.record.value, 8500);
  });
}

class FakeRemote implements MonthlyLimitRemote {
  final values = <String, double>{};
  final started = Completer<void>();
  bool offline = false;
  int writes = 0;
  Completer<double?>? fetchGate;
  Completer<void>? saveGate;

  void _start() {
    if (!started.isCompleted) started.complete();
    if (offline) throw StateError('offline');
  }

  @override
  Future<double?> fetch(String userId) async {
    _start();
    return fetchGate == null ? values[userId] : await fetchGate!.future;
  }

  @override
  Future<void> save(String userId, double value) async {
    _start();
    if (saveGate != null) await saveGate!.future;
    values[userId] = value;
    writes++;
  }
}
