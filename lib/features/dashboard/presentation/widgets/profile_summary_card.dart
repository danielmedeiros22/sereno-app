import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/profile_name_provider.dart';
import '../../../auth/presentation/widgets/edit_profile_name_button.dart';
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
    final name = owner == null ? 'Visitante' : ref.watch(profileNameProvider);
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
          SizedBox(width: 56, height: 56, child: ClipOval(child: image)),
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
          if (owner != null) const EditProfileNameButton(),
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
