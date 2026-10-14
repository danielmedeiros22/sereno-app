import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/financial_record_sync_provider.dart';
import '../transactions/presentation/providers/transaction_provider.dart';
import 'spaces_provider.dart';

class SpaceSelector extends ConsumerWidget {
  const SpaceSelector(
      {super.key, this.value, this.onChanged, this.allowAll = true});
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool allowAll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = [...ref.watch(availableSpacesProvider)];
    final selected =
        onChanged == null ? ref.watch(selectedSpaceProvider) : value;
    if (selected != null && !spaces.any((space) => space.id == selected)) {
      spaces.add(PersonalSpace(selected, 'Espaço selecionado', '📁'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
          key: ValueKey(
              'space:$selected:${spaces.map((s) => s.name).join(',')}'),
          initialValue: selected ?? (allowAll ? '' : 'personal'),
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Espaço'),
          items: [
            if (allowAll)
              const DropdownMenuItem(
                  value: '', child: Text('Todos os espaços')),
            for (final space in spaces)
              DropdownMenuItem(
                  value: space.id,
                  child: Text('${space.icon} ${space.name}',
                      overflow: TextOverflow.ellipsis))
          ],
          onChanged: (id) {
            final next = id == '' ? null : id;
            if (onChanged != null) {
              onChanged!(next);
            } else {
              ref.read(selectedSpaceProvider.notifier).state = next;
            }
          }),
      if (ref.watch(spaceListProvider).hasError ||
          ref.watch(financialSyncFailedProvider('space')))
        const Text(
            'Não foi possível atualizar os espaços. Exibindo os dados disponíveis.'),
    ]);
  }
}
