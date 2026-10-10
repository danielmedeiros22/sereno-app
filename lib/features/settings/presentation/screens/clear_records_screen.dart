import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../journal/data/journal_model.dart';
import '../../../journal/presentation/providers/journal_provider.dart';
import '../../../recurring/data/recurring_model.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../transactions/data/transaction_model.dart';
import '../../../transactions/data/transaction_deletion_period.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/local_record_deletion.dart';

class ClearRecordsScreen extends ConsumerStatefulWidget {
  const ClearRecordsScreen({super.key});

  @override
  ConsumerState<ClearRecordsScreen> createState() => _ClearRecordsScreenState();
}

class _ClearRecordsScreenState extends ConsumerState<ClearRecordsScreen> {
  final _selected = <String>{};
  static const _labels = {
    'income': 'Entradas',
    'expense': 'Saídas',
    'journal': 'Diário financeiro',
    'recurring': 'Contas recorrentes',
  };
  DeletionPeriodType _type = DeletionPeriodType.month;
  DateTime _date = DateTime.now();
  bool _busy = false;
  bool _confirming = false;

  String get _periodLabel => switch (_type) {
        DeletionPeriodType.day => DateFormat('dd/MM/yyyy').format(_date),
        DeletionPeriodType.month => DateFormat('MM/yyyy').format(_date),
        DeletionPeriodType.year => '${_date.year}',
        DeletionPeriodType.all => 'Todo o histórico',
      };

  Future<void> _review() async {
    setState(() => _busy = true);
    final owner = ref.read(transactionOwnerProvider);
    final selected = Set<String>.of(_selected);
    final period = TransactionDeletionPeriod(_type, _date);
    var deleted = 0;
    var deleting = false;
    try {
      var transactions = <TransactionModel>[];
      var journal = <JournalEntry>[];
      var recurring = <RecurringModel>[];
      if (selected.contains('income') || selected.contains('expense')) {
        final service = ref.read(localTransactionServiceProvider);
        // Require a successful cloud read before reviewing account records.
        // Await the service's shared future even if automatic sync is running.
        await service.synchronize();
        transactions = (await service.getAll())
            .where(
                (tx) => selected.contains(tx.type) && period.contains(tx.date))
            .toList();
      }
      if (selected.contains('journal')) {
        journal = (await ref.read(localJournalServiceProvider).getAll())
            .where((row) => period.contains(row.entryDate))
            .toList();
      }
      if (selected.contains('recurring')) {
        recurring = (await ref.read(localRecurringServiceProvider).getAll())
            .where((row) => period.contains(row.createdAt))
            .toList();
      }
      if (!mounted || owner != ref.read(transactionOwnerProvider)) return;
      final total = transactions.length + journal.length + recurring.length;
      if (total == 0) {
        _message('Nenhum registro encontrado para esta seleção.');
        return;
      }
      final summary = [
        if (selected.contains('income'))
          'Entradas: ${transactions.where((tx) => tx.isIncome).length}',
        if (selected.contains('expense'))
          'Saídas: ${transactions.where((tx) => tx.isExpense).length}',
        if (selected.contains('journal')) 'Diário: ${journal.length}',
        if (selected.contains('recurring'))
          'Contas recorrentes: ${recurring.length}',
      ].join('\n');
      setState(() => _confirming = true);
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DeletionConfirmation(
          summary:
              'Período: $_periodLabel\n$summary\n\nTotal: $total registros.',
          scope: owner == null
              ? 'A exclusão afeta os dados deste dispositivo.'
              : 'Entradas e saídas serão excluídas da conta e dos outros dispositivos ao sincronizar. Diário e contas recorrentes serão excluídos somente deste dispositivo.',
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (confirmed != true) return;
      if (owner != ref.read(transactionOwnerProvider)) {
        _message('A conta mudou. Revise a seleção novamente.');
        return;
      }
      deleting = true;
      if (transactions.isNotEmpty) {
        deleted += await ref
            .read(transactionListProvider.notifier)
            .deleteReviewed(transactions);
      }
      if (!mounted || owner != ref.read(transactionOwnerProvider)) return;
      if (journal.isNotEmpty) {
        deleted += await LocalRecordDeletion.journal(
            journal.map((row) => row.toJson()).toList());
        await ref.read(journalListProvider.notifier).load();
      }
      if (!mounted || owner != ref.read(transactionOwnerProvider)) return;
      if (recurring.isNotEmpty) {
        deleted += await LocalRecordDeletion.recurring(
            recurring.map((row) => row.toJson()).toList());
        await ref.read(recurringListProvider.notifier).load();
      }
      if (!mounted) return;
      final pending = transactions.isNotEmpty &&
          ref.read(transactionSyncStatusProvider) !=
              TransactionSyncStatus.synced &&
          owner != null;
      _message('$deleted registros excluídos.'
          '${deleted < total ? ' Registros alterados após a revisão foram preservados.' : ''}'
          '${pending ? ' A exclusão da conta aguarda sincronização.' : ''}');
    } catch (_) {
      if (mounted) {
        _message(deleting
            ? 'A limpeza foi interrompida. $deleted exclusões concluídas. Revise os registros restantes antes de tentar novamente.'
            : 'Não foi possível carregar todos os registros. Nada foi excluído. Verifique a conexão e tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Limpar registros')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Atenção: a exclusão não pode ser desfeita no aplicativo.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
              'Escolha o que excluir. Tema, login, teto mensal e orçamentos por categoria serão mantidos.'),
          CheckboxListTile(
            title: const Text('Selecionar tudo'),
            value: _selected.length == _labels.length,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                      _selected.clear();
                      if (value == true) _selected.addAll(_labels.keys);
                    }),
          ),
          for (final item in _labels.entries)
            CheckboxListTile(
              title: Text(item.value),
              value: _selected.contains(item.key),
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                        if (value == true) {
                          _selected.add(item.key);
                        } else {
                          _selected.remove(item.key);
                        }
                      }),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DeletionPeriodType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Período'),
            items: const [
              DropdownMenuItem(
                  value: DeletionPeriodType.day, child: Text('Dia')),
              DropdownMenuItem(
                  value: DeletionPeriodType.month, child: Text('Mês')),
              DropdownMenuItem(
                  value: DeletionPeriodType.year, child: Text('Ano')),
              DropdownMenuItem(
                  value: DeletionPeriodType.all,
                  child: Text('Todo o histórico')),
            ],
            onChanged: _busy ? null : (value) => setState(() => _type = value!),
          ),
          if (_type != DeletionPeriodType.all)
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(_periodLabel),
              subtitle: const Text('Escolher data de referência'),
              onTap: _busy
                  ? null
                  : () async {
                      final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2200, 12, 31));
                      if (date != null && mounted) setState(() => _date = date);
                    },
            ),
          const SizedBox(height: 12),
          const Text(
              'O filtro usa a data do lançamento, a data da anotação do diário e a data de criação da conta recorrente. Excluir uma recorrência também remove sua programação futura.'),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _busy || _selected.isEmpty ? null : _review,
            icon: _busy && !_confirming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline),
            label: Text(_confirming
                ? 'Revisão aberta'
                : _busy
                    ? 'Aguarde…'
                    : 'Revisar exclusão'),
          ),
        ]),
      ),
    );
  }
}

class _DeletionConfirmation extends StatefulWidget {
  const _DeletionConfirmation({required this.summary, required this.scope});
  final String summary;
  final String scope;

  @override
  State<_DeletionConfirmation> createState() => _DeletionConfirmationState();
}

class _DeletionConfirmationState extends State<_DeletionConfirmation> {
  bool _authorized = false;
  String _text = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.summary),
                const SizedBox(height: 12),
                Text(widget.scope),
                const SizedBox(height: 12),
                const Text('Esta ação não pode ser desfeita no aplicativo.',
                    style: TextStyle(color: Colors.red)),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title:
                        const Text('Autorizo a exclusão dos registros acima.'),
                    value: _authorized,
                    onChanged: (value) =>
                        setState(() => _authorized = value == true)),
                TextField(
                    decoration: const InputDecoration(
                        labelText: 'Digite EXCLUIR para confirmar'),
                    onChanged: (value) => setState(() => _text = value)),
              ],
            ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _authorized && _text == 'EXCLUIR'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Excluir registros')),
        ],
      );
}
