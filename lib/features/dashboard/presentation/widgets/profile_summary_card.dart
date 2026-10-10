import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/presentation/providers/summary_period.dart';
import '../providers/avatar_provider.dart';
import 'segmented_limit_progress.dart';

class ProfileSummaryCard extends ConsumerStatefulWidget {
  const ProfileSummaryCard(
      {super.key, required this.percent, required this.onLimitsTap});
  final double percent;
  final VoidCallback onLimitsTap;

  @override
  ConsumerState<ProfileSummaryCard> createState() => _ProfileSummaryCardState();
}

class _ProfileSummaryCardState extends ConsumerState<ProfileSummaryCard> {
  bool _changing = false;

  Future<void> _changePhoto() async {
    final owner = ref.read(transactionOwnerProvider);
    final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escolher imagem'),
                  subtitle: Text(owner == null
                      ? 'Salva apenas neste dispositivo'
                      : 'Foto privada, sincronizada com sua conta'),
                  onTap: () => Navigator.pop(context, 'pick')),
              ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(owner == null
                      ? 'Usar ícone padrão'
                      : 'Usar foto da conta Google'),
                  onTap: () => Navigator.pop(context, 'reset')),
              ListTile(
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(context)),
            ])));
    if (!mounted ||
        choice == null ||
        owner != ref.read(transactionOwnerProvider)) {
      return;
    }
    setState(() => _changing = true);
    try {
      final bytes =
          choice == 'pick' ? await ref.read(avatarPickerProvider)() : null;
      if (!mounted ||
          (choice == 'pick' && bytes == null) ||
          owner != ref.read(transactionOwnerProvider)) {
        return;
      }
      await ref.read(avatarProvider.notifier).change(bytes);
      if (mounted && owner == ref.read(transactionOwnerProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(owner == null
                ? 'Imagem salva neste dispositivo.'
                : 'Foto atualizada na sua conta.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível trocar a imagem. Verifique a conexão e tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _selectMonth() async {
    final owner = ref.read(transactionOwnerProvider);
    final current = ref.read(selectedMonthProvider);
    final type = ref.read(summaryPeriodTypeProvider);
    final dates = ref.read(transactionListProvider).valueOrNull ?? [];
    if (type != SummaryPeriodType.month) {
      final candidates = [
        DateTime.now(),
        current,
        ...dates.map((tx) => tx.date)
      ];
      final years = candidates.map((date) => date.year).toList()..sort();
      final selection = await showDatePicker(
          context: context,
          locale: const Locale('pt', 'BR'),
          initialDate: current,
          firstDate: DateTime(years.first - 1),
          lastDate: DateTime(years.last + 1, 12, 31),
          helpText: type == SummaryPeriodType.day
              ? 'Escolher dia'
              : 'Escolher um dia da semana',
          confirmText: 'Consultar',
          cancelText: 'Cancelar');
      if (mounted &&
          selection != null &&
          owner == ref.read(transactionOwnerProvider) &&
          type == ref.read(summaryPeriodTypeProvider)) {
        ref.read(selectedMonthProvider.notifier).state = selection;
      }
      return;
    }
    final years = {
      DateTime.now().year,
      current.year,
      ...dates.map((tx) => tx.date.year)
    }.toList()
      ..sort();
    var year = current.year;
    var month = current.month;
    final selection = await showDialog<DateTime>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Escolher mês'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<int>(
                        initialValue: year,
                        decoration: const InputDecoration(labelText: 'Ano'),
                        items: years
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text('$value')))
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => year = value!)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                        initialValue: month,
                        decoration: const InputDecoration(labelText: 'Mês'),
                        items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                                value: index + 1,
                                child: Text(DateFormat.MMMM('pt_BR')
                                    .format(DateTime(year, index + 1))))),
                        onChanged: (value) =>
                            setDialogState(() => month = value!)),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, DateTime(year, month)),
                        child: const Text('Consultar')),
                  ],
                )));
    if (mounted &&
        selection != null &&
        owner == ref.read(transactionOwnerProvider) &&
        type == ref.read(summaryPeriodTypeProvider)) {
      ref.read(selectedMonthProvider.notifier).state = selection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owner = ref.watch(transactionOwnerProvider);
    final user = owner == null ? null : ref.watch(currentUserProvider);
    final name = user?.userMetadata?['full_name'] as String? ?? 'Visitante';
    final bytes = ref.watch(avatarProvider).valueOrNull;
    final googlePhoto = user?.userMetadata?['avatar_url'] as String?;
    final period = ref.watch(summaryPeriodProvider);
    final count = ref.watch(selectedMonthTransactionsProvider).length;
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final fallback = ColoredBox(
        color: theme.colorScheme.primaryContainer,
        child: Center(child: Text(initial, style: theme.textTheme.titleLarge)));
    final image = bytes != null
        ? Image.memory(bytes,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
        : googlePhoto != null
            ? Image.network(googlePhoto,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
            : fallback;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Tooltip(
              message: 'Trocar imagem',
              child: Semantics(
                  button: true,
                  label: 'Trocar imagem',
                  child: InkWell(
                      onTap: _changing ? null : _changePhoto,
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(children: [
                            Positioned.fill(child: ClipOval(child: image)),
                            Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: theme.colorScheme.primary,
                                    child: _changing
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Icon(Icons.photo_camera,
                                            size: 12, color: Colors.white))),
                          ]))))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Minhas finanças', style: theme.textTheme.titleMedium),
                Text('$name · Espaço pessoal',
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final type in SummaryPeriodType.values)
            ChoiceChip(
                label: Text(switch (type) {
                  SummaryPeriodType.day => 'Dia',
                  SummaryPeriodType.week => 'Semana',
                  SummaryPeriodType.month => 'Mês',
                }),
                selected: period.type == type,
                onSelected: (_) =>
                    ref.read(summaryPeriodTypeProvider.notifier).state = type),
        ]),
        Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              TextButton.icon(
                  onPressed: _selectMonth,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(period.label)),
              Text('$count ${count == 1 ? 'lançamento' : 'lançamentos'}',
                  style: theme.textTheme.bodySmall),
            ]),
        if (period.type != SummaryPeriodType.month)
          Text('Gastos do período em relação ao teto mensal',
              style: theme.textTheme.bodySmall),
        InkWell(
            onTap: widget.onLimitsTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SegmentedLimitProgress(percent: widget.percent))),
        TextButton(
            onPressed: widget.onLimitsTap,
            child: const Text('Ver meus limites')),
      ]),
    );
  }
}
