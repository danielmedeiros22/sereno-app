import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/financial_record_sync_provider.dart';
import '../transactions/presentation/providers/transaction_provider.dart';
import 'spaces_provider.dart';

class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({super.key});
  Future<void> _edit(BuildContext context, WidgetRef ref,
          [PersonalSpace? original]) =>
      showDialog<void>(
          context: context, builder: (_) => _SpaceEditor(original: original));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(spaceListProvider);
    final owner = ref.watch(transactionOwnerProvider);
    final failed = ref.watch(financialSyncFailedProvider('space'));
    return Scaffold(
        appBar: AppBar(
            title: const Text('Meus espaços'),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop()),
            actions: [
              IconButton(
                  tooltip: 'Atualizar espaços',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(spaceListProvider.notifier).synchronize()),
              const SizedBox(width: 16)
            ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(owner == null
              ? 'Espaços salvos neste dispositivo.'
              : failed
                  ? 'Espaços salvos neste dispositivo. Sincronização pendente.'
                  : 'Espaços individuais da sua conta. Alterações sincronizam entre dispositivos.'),
          const SizedBox(height: 12),
          const Text(
              'Organize entradas e saídas por espaço. O teto mensal, os orçamentos, as contas recorrentes e os alertas continuam sendo da conta inteira. O espaço Pessoal é permanente.'),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Novo espaço')),
          const SizedBox(height: 16),
          ...spaces.when(
              data: (list) => list
                  .map((space) => ListTile(
                      leading: Text(space.icon,
                          style: const TextStyle(fontSize: 24)),
                      title: Text(space.name),
                      subtitle: Text(space.id == 'personal'
                          ? 'Padrão dos lançamentos anteriores'
                          : 'Espaço individual'),
                      trailing: space.id == 'personal'
                          ? null
                          : IconButton(
                              tooltip: 'Editar ${space.name}',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(context, ref, space))))
                  .toList(),
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, __) => [
                    const Text(
                        'Não foi possível carregar os espaços. Tente atualizar.')
                  ]),
        ]));
  }
}

class _SpaceEditor extends ConsumerStatefulWidget {
  const _SpaceEditor({this.original});
  final PersonalSpace? original;
  @override
  ConsumerState<_SpaceEditor> createState() => _SpaceEditorState();
}

class _SpaceEditorState extends ConsumerState<_SpaceEditor> {
  late final TextEditingController _name;
  late final TextEditingController _icon;
  late final String? _owner;
  late final SpaceNotifier _notifier;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(transactionOwnerProvider);
    _notifier = ref.read(spaceListProvider.notifier);
    _name = TextEditingController(text: widget.original?.name);
    _icon = TextEditingController(text: widget.original?.icon ?? '📁');
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_owner != ref.read(transactionOwnerProvider)) {
      setState(() => _error = 'A conta mudou. Feche e tente novamente.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _notifier.save(_name.text, _icon.text, id: widget.original?.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e) {
            ArgumentError(:final message) => '$message',
            StateError(:final message) => message,
            _ => 'Não foi possível salvar o espaço. Tente novamente.',
          };
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.original == null ? 'Novo espaço' : 'Editar espaço'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              maxLength: 40,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Nome do espaço')),
          const SizedBox(height: 12),
          TextField(
              controller: _icon,
              maxLength: 1,
              enabled: !_saving,
              decoration: const InputDecoration(
                  labelText: 'Emoji',
                  helperText: 'Use o teclado de emojis ou cole um emoji.')),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ])),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar'))
        ],
      ));
}
