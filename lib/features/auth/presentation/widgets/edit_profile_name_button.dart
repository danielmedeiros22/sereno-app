import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_name_provider.dart';

class EditProfileNameButton extends ConsumerWidget {
  const EditProfileNameButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserProvider) == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Editar nome',
      icon: const Icon(Icons.edit_outlined, size: 18),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const _EditNameDialog(),
      ),
    );
  }
}

class _EditNameDialog extends ConsumerStatefulWidget {
  const _EditNameDialog();
  @override
  ConsumerState<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<_EditNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _controller =
      TextEditingController(text: ref.read(profileNameProvider));
  String? _owner;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(currentUserProvider)?.id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_owner != ref.read(currentUserProvider)?.id) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileNameProvider.notifier).save(_controller.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Não foi possível salvar. Verifique a conexão e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('Editar nome'),
          content: SizedBox(
              width: 360,
              child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _controller,
                        enabled: !_saving,
                        autofocus: true,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Nome de exibição'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Informe seu nome.'
                                : null,
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const Text(
                          'Seu e-mail e login permanecem os mesmos. O nome será atualizado nos seus dispositivos.'),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ],
                  ))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar')),
          ],
        ),
      );
}
