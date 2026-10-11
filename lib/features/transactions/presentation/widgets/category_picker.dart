import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/default_categories.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class CategoryPicker extends ConsumerWidget {
  const CategoryPicker(
      {super.key,
      required this.type,
      required this.selected,
      required this.onChanged});
  final String type;
  final CategoryItem? selected;
  final ValueChanged<CategoryItem> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref
        .watch(availableCategoriesProvider)
        .where((item) => item.type == type);
    final loading = ref.watch(categoryListProvider).isLoading;
    final failed = ref.watch(categorySyncFailedProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final item in categories)
          ChoiceChip(
              label: Text('${item.icon}  ${item.name}'),
              selected: item.key == selected?.key,
              onSelected: (_) => onChanged(item)),
        ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar categoria'),
            onPressed: loading
                ? null
                : () async {
                    final owner = ref.read(transactionOwnerProvider);
                    final item = await showDialog<CategoryItem>(
                        context: context,
                        builder: (_) => _CategoryDialog(type: type));
                    if (context.mounted &&
                        item != null &&
                        owner == ref.read(transactionOwnerProvider)) {
                      onChanged(item);
                    }
                  }),
      ]),
      if (ref.watch(categoryListProvider).hasError)
        TextButton(
            onPressed: () => ref.read(categoryListProvider.notifier).load(),
            child: const Text(
                'Não foi possível ler as categorias. Tentar novamente')),
      if (failed)
        TextButton(
            onPressed: () =>
                ref.read(categoryListProvider.notifier).synchronize(),
            child: const Text(
                'Categorias salvas neste dispositivo. Tentar sincronizar')),
    ]);
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({required this.type});
  final String type;
  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _name = TextEditingController();
  final _emoji = TextEditingController(text: '🏷️');
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final owner = ref.read(transactionOwnerProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final item = await ref
          .read(categoryListProvider.notifier)
          .add(_name.text, _emoji.text, widget.type);
      if (mounted) {
        if (owner != ref.read(transactionOwnerProvider)) {
          Navigator.pop(context);
        } else {
          Navigator.pop(context, item);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ArgumentError
            ? error.message.toString()
            : 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('Adicionar categoria'),
          content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.type == 'expense'
                      ? 'Categoria de saída'
                      : 'Categoria de entrada'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _name,
                      autofocus: true,
                      enabled: !_saving,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Nome da categoria')),
                  TextField(
                      controller: _emoji,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                          labelText: 'Emoji',
                          helperText:
                              'Use o teclado de emojis ou cole um emoji.')),
                  const SizedBox(height: 12),
                  const Text('Ou escolha uma sugestão:'),
                  Wrap(spacing: 4, children: [
                    for (final emoji in [
                      '🏷️',
                      '☕',
                      '✈️',
                      '🏋️',
                      '🎨',
                      '🧰',
                      '🌱',
                      '🐶',
                      '💼',
                      '🎵',
                      '👨‍👩‍👧‍👦',
                      '🇧🇷'
                    ])
                      IconButton(
                          tooltip: 'Usar $emoji',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _emoji.text = emoji),
                          icon: Text(emoji,
                              style: const TextStyle(fontSize: 24))),
                  ]),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                  Text(ref.watch(transactionOwnerProvider) == null
                      ? 'Visitante: salva apenas neste dispositivo.'
                      : 'Salva na conta e sincroniza entre dispositivos. Sem conexão, o envio fica pendente.'),
                ],
              ))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Criar categoria'))
          ],
        ),
      );
}
