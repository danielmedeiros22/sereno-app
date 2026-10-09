import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/monthly_limit_provider.dart';
import 'termometro_orb.dart';

class MonthlyLimitSheet extends ConsumerStatefulWidget {
  const MonthlyLimitSheet(
      {super.key,
      required this.currentLimit,
      required this.currentSpent,
      required this.owner,
      required this.onChanged});
  final double currentLimit;
  final double currentSpent;
  final String? owner;
  final Future<void> Function(double) onChanged;

  @override
  ConsumerState<MonthlyLimitSheet> createState() => MonthlyLimitSheetState();
}

class MonthlyLimitSheetState extends ConsumerState<MonthlyLimitSheet> {
  late double _limit;
  late double _savedLimit;
  bool _saving = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _limit = widget.currentLimit;
    _savedLimit = _limit;
    _textController = TextEditingController(text: _formatInput(_limit));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  double get _percent => _limit > 0 ? (widget.currentSpent / _limit) * 100 : 0;

  String _formatInput(double value) => value
      .toStringAsFixed(value == value.roundToDouble() ? 0 : 2)
      .replaceAll('.', ',');

  double? get _draft {
    final value =
        double.tryParse(_textController.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 100 || value > 50000) {
      return null;
    }
    return (value * 100).round() / 100;
  }

  void _applyLimit(String text) {
    if (ref.read(monthlyLimitOwnerProvider) != widget.owner) return;
    setState(() => _limit = _draft ?? _savedLimit);
  }

  Future<void> _confirmLimit() async {
    final value = _draft;
    if (_saving || value == null || value == _savedLimit) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar alteração do teto?'),
        content: Text('Teto atual: ${currency.format(_savedLimit)}\n'
            'Novo teto: ${currency.format(value)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true ||
        ref.read(monthlyLimitOwnerProvider) != widget.owner) {
      setState(() => _saving = false);
      return;
    }
    try {
      await widget.onChanged(value);
      if (!mounted) return;
      setState(() {
        _savedLimit = value;
        _limit = value;
        _textController.text = _formatInput(value);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Teto mensal salvo.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível salvar o teto mensal. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.riskFor(_percent);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final limitState = ref.watch(monthlyLimitProvider);
    ref.listen(monthlyLimitProvider, (_, next) {
      final value = next.valueOrNull?.record.value;
      if (value != null &&
          value != _savedLimit &&
          ref.read(monthlyLimitOwnerProvider) == widget.owner) {
        final wasEdited = _textController.text != _formatInput(_savedLimit);
        setState(() {
          _savedLimit = value;
          if (!wasEdited && !_saving) {
            _limit = value;
            _textController.text = _formatInput(value);
          }
        });
      }
    });
    ref.listen(monthlyLimitOwnerProvider, (_, owner) {
      if (owner != widget.owner && mounted) Navigator.of(context).pop();
    });

    return Container(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.outline,
                        borderRadius: BorderRadius.circular(2)))),
            Text('Meus limites', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
            _LimitSyncStatus(
                state: limitState.valueOrNull, isGuest: widget.owner == null),
            const SizedBox(height: 24),
            Center(child: TermometroOrb(percent: _percent, size: 140)),
            const SizedBox(height: 16),
            Center(
                child: Text(AppColors.moodFor(_percent),
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: color))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('TETO MENSAL', style: theme.textTheme.labelSmall),
              SizedBox(
                  width: 140,
                  child: TextField(
                      controller: _textController,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      style:
                          theme.textTheme.headlineLarge?.copyWith(color: color),
                      decoration: const InputDecoration(
                          prefixText: 'R\$ ', border: InputBorder.none),
                      onChanged: _applyLimit,
                      onSubmitted: (_) => _confirmLimit())),
            ]),
            if (_draft == null)
              const Text('Informe um valor entre R\$ 100 e R\$ 50.000.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving || _draft == null || _draft == _savedLimit
                  ? null
                  : _confirmLimit,
              child: Text(_saving ? 'Salvando…' : 'Salvar alteração'),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Gasto atual', style: theme.textTheme.bodySmall),
              Text(currency.format(widget.currentSpent),
                  style: theme.textTheme.titleMedium)
            ]),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: (_percent / 100).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation(color))),
          ])),
    );
  }
}

class _LimitSyncStatus extends ConsumerWidget {
  const _LimitSyncStatus({required this.state, required this.isGuest});

  final MonthlyLimitState? state;
  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = state;
    final configured = ref.watch(monthlyLimitServiceProvider).remote != null;
    final message = isGuest
        ? 'Salvo neste navegador'
        : value?.syncing == true
            ? 'Sincronizando teto…'
            : value?.syncFailed == true
                ? 'Sem sincronização. Tentaremos novamente.'
                : !configured || value?.record.pending == true
                    ? 'Salvo neste navegador · aguardando sincronização'
                    : 'Teto atualizado com sua conta';
    return Row(children: [
      Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
      if (!isGuest && configured && value?.syncFailed == true)
        IconButton(
            tooltip: 'Tentar sincronizar novamente',
            onPressed: () =>
                ref.read(monthlyLimitProvider.notifier).synchronize(),
            icon: const Icon(Icons.sync)),
    ]);
  }
}
