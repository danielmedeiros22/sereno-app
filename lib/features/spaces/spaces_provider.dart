import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/account_record_store.dart';
import '../../core/services/financial_record_sync_provider.dart';
import '../transactions/data/category_service.dart';
import '../transactions/data/default_categories.dart';
import '../transactions/presentation/providers/transaction_provider.dart';

class PersonalSpace {
  const PersonalSpace(this.id, this.name, this.icon);
  final String id, name, icon;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon};
  factory PersonalSpace.fromJson(Map<String, dynamic> json) => PersonalSpace(
      json['id'] as String, json['name'] as String, json['icon'] as String);
}

const standardSpaces = [
  PersonalSpace('personal', 'Pessoal', '👤'),
  PersonalSpace('home', 'Casa', '🏠'),
  PersonalSpace('business', 'Empresa', '💼'),
  PersonalSpace('travel', 'Viagem', '✈️'),
];

class SpaceService {
  SpaceService({String? owner, AccountRecordRemote? remote})
      : store = AccountRecordStore(
            kind: 'space',
            guestKey: 'personal_spaces',
            owner: owner,
            remote: remote);
  final AccountRecordStore store;
  Future<List<PersonalSpace>> getAll() async {
    final spaces = {for (final space in standardSpaces) space.id: space};
    for (final json in await store.getAll()) {
      final space = PersonalSpace.fromJson(json);
      if (space.id != 'personal') spaces[space.id] = space;
    }
    return spaces.values.toList();
  }

  Future<PersonalSpace> save(String name, String icon, {String? id}) async {
    if (id == 'personal') throw StateError('O espaço Pessoal é permanente.');
    final valid = CategoryService.validate(name, icon, 'expense');
    final all = await getAll();
    if (all.any((s) =>
        s.id != id && categoryNameKey(s.name) == categoryNameKey(valid.name))) {
      throw StateError('Já existe um espaço com esse nome.');
    }
    final space =
        PersonalSpace(id ?? const Uuid().v4(), valid.name, valid.icon);
    await store.save(space.toJson());
    return space;
  }
}

final spaceServiceProvider = Provider<SpaceService>((ref) => SpaceService(
    owner: ref.watch(transactionOwnerProvider),
    remote: ref.watch(financialRecordRemoteProvider)));
final spaceListProvider =
    StateNotifierProvider<SpaceNotifier, AsyncValue<List<PersonalSpace>>>(
        (ref) {
  final service = ref.watch(spaceServiceProvider);
  final notifier = SpaceNotifier(
      service,
      (failed) => ref
          .read(financialSyncFailedProvider('space').notifier)
          .state = failed);
  installFinancialSync(ref, service.store.remote, notifier.synchronize);
  return notifier;
});

class SpaceNotifier extends FinancialListNotifier<PersonalSpace> {
  SpaceNotifier(this.service, super.onFailure) {
    initialize();
  }
  final SpaceService service;
  bool _saving = false;
  @override
  Future<List<PersonalSpace>> readRecords() => service.getAll();
  @override
  Future<void> syncRecords() => service.store.synchronize();
  Future<PersonalSpace> save(String name, String icon, {String? id}) async {
    if (_saving) throw StateError('Aguarde a gravação atual.');
    _saving = true;
    try {
      final space = await service.save(name, icon, id: id);
      await changed();
      return space;
    } finally {
      _saving = false;
    }
  }
}

final availableSpacesProvider = Provider<List<PersonalSpace>>((ref) {
  final catalog = {
    for (final space
        in ref.watch(spaceListProvider).valueOrNull ?? standardSpaces)
      space.id: space
  };
  // Records may arrive before their catalog. Keep those records selectable.
  for (final tx in ref.watch(transactionListProvider).valueOrNull ?? []) {
    catalog.putIfAbsent(
        tx.spaceId, () => PersonalSpace(tx.spaceId, tx.spaceName, '📁'));
  }
  return catalog.values.toList();
});

final selectedSpaceLabelProvider = Provider<String>((ref) {
  final id = ref.watch(selectedSpaceProvider);
  if (id == null) return 'Todos os espaços';
  return ref
          .watch(availableSpacesProvider)
          .where((s) => s.id == id)
          .map((s) => '${s.icon} ${s.name}')
          .firstOrNull ??
      'Espaço selecionado';
});
