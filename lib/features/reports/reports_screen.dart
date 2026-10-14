import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../transactions/presentation/providers/summary_period.dart';
import '../transactions/presentation/providers/transaction_provider.dart';
import '../transactions/presentation/widgets/transaction_sync_banner.dart';
import 'report_data.dart';
import '../spaces/space_selector.dart';
import '../spaces/spaces_provider.dart';

String _money(int cents) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final notifier = ref.read(transactionListProvider.notifier);
      await notifier.load();
      await notifier.synchronize();
      await ref.read(spaceListProvider.notifier).synchronize();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _chooseDate() async {
    final owner = ref.read(transactionOwnerProvider);
    final current = ref.read(selectedMonthProvider);
    final dates = [
      DateTime.now(),
      current,
      ...?ref
          .read(transactionListProvider)
          .valueOrNull
          ?.map((tx) => tx.date.toLocal())
    ];
    final years = dates.map((date) => date.year).toList()..sort();
    final selected = await showDatePicker(
        context: context,
        locale: const Locale('pt', 'BR'),
        initialDate: current,
        firstDate: DateTime(years.first - 1),
        lastDate: DateTime(years.last + 1, 12, 31),
        helpText: 'Escolher data de referência',
        confirmText: 'Consultar');
    if (mounted &&
        selected != null &&
        owner == ref.read(transactionOwnerProvider)) {
      ref.read(selectedMonthProvider.notifier).state = selected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(summaryPeriodProvider);
    final report = ref.watch(reportProvider);
    return Scaffold(
      appBar: AppBar(
          title: const Text('Relatórios'),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop()),
          actions: [
            IconButton(
                tooltip: 'Atualizar relatórios',
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh)),
            const SizedBox(width: 16)
          ]),
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const TransactionSyncBanner(),
                const SizedBox(height: 16),
                const SpaceSelector(),
                const SizedBox(height: 16),
                Wrap(
                    spacing: 8,
                    children: SummaryPeriodType.values
                        .map((type) => ChoiceChip(
                            label: Text(switch (type) {
                              SummaryPeriodType.day => 'Dia',
                              SummaryPeriodType.week => 'Semana',
                              SummaryPeriodType.month => 'Mês'
                            }),
                            selected: period.type == type,
                            onSelected: (_) => ref
                                .read(summaryPeriodTypeProvider.notifier)
                                .state = type))
                        .toList()),
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: _chooseDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(period.label))),
                const Text(
                    'O período é compartilhado com o painel. Valores calculados a partir dos lançamentos disponíveis; contas futuras não entram nos totais.'),
                const SizedBox(height: 20),
                ...report.when(
                    data: (data) => _content(data),
                    loading: () =>
                        [const Center(child: CircularProgressIndicator())],
                    error: (_, __) => [
                          const Text(
                              'Não foi possível carregar os lançamentos.'),
                          TextButton(
                              onPressed: _refresh,
                              child: const Text('Tentar novamente'))
                        ]),
              ])),
    );
  }

  List<Widget> _content(ReportData data) {
    return [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _total('Entradas', data.income, AppColors.income),
        _total('Saídas', data.expense, AppColors.expense),
        _total('Saldo do período', data.income - data.expense,
            Theme.of(context).colorScheme.primary),
      ]),
      const SizedBox(height: 20),
      Text(
          '${data.count} ${data.count == 1 ? 'lançamento' : 'lançamentos'} no período'),
      if (data.count == 0)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
                'Nenhum lançamento neste período. Escolha outra data ou registre uma movimentação.')),
      _section(
          'Entradas e saídas',
          Column(children: [
            _bar('Entradas', data.income, math.max(data.income, data.expense),
                AppColors.income),
            _bar('Saídas', data.expense, math.max(data.income, data.expense),
                AppColors.expense),
          ])),
      _section(
          'Gastos por categoria',
          data.categories.isEmpty
              ? const Text('Nenhuma saída no período.')
              : Column(
                  children: data.categories
                      .map((cat) => _bar(
                          '${cat.icon} ${cat.name} · ${NumberFormat('0.#', 'pt_BR').format(data.expense == 0 ? 0 : cat.cents * 100 / data.expense)}%',
                          cat.cents,
                          data.expense,
                          AppColors.expense))
                      .toList())),
      _section(
          data.period.type == SummaryPeriodType.day
              ? 'Gastos por hora'
              : 'Gastos por dia',
          data.expense == 0
              ? const Text('Nenhuma saída no período.')
              : _evolution(data)),
    ];
  }

  Widget _total(String label, int cents, Color color) => SizedBox(
      width: 240,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    const SizedBox(height: 8),
                    Text(_money(cents),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color))
                  ]))));

  Widget _section(String title, Widget content) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    content
                  ]))));

  Widget _bar(String label, int cents, int maximum, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label — ${_money(cents)}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: maximum == 0 ? 0 : (cents / maximum).clamp(0, 1),
            color: color,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4)),
      ]));

  Widget _evolution(ReportData data) {
    final maximum = data.buckets.fold<int>(0, math.max);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
          'Toque nas barras para ver o valor. Deslize para consultar todo o período.'),
      const SizedBox(height: 12),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.buckets.length, (i) {
                final date = DateTime(data.period.start.year,
                    data.period.start.month, data.period.start.day + i);
                final label = data.period.type == SummaryPeriodType.day
                    ? '${i}h'
                    : DateFormat('dd/MM').format(date);
                final text = '$label: ${_money(data.buckets[i])}';
                return Semantics(
                    label: text,
                    child: Tooltip(
                        message: text,
                        triggerMode: TooltipTriggerMode.tap,
                        child: SizedBox(
                            width: 48,
                            child: Column(children: [
                              SizedBox(
                                  height: 150,
                                  child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                          width: 24,
                                          height: maximum == 0
                                              ? 0
                                              : data.buckets[i] / maximum * 150,
                                          decoration: BoxDecoration(
                                              color: AppColors.expense,
                                              borderRadius:
                                                  BorderRadius.circular(4))))),
                              const SizedBox(height: 8),
                              Text(label,
                                  style: Theme.of(context).textTheme.bodySmall)
                            ]))));
              }))),
    ]);
  }
}
