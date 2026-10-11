import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/financial_record_sync_provider.dart';
import '../../../budget/data/local_budget_service.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../recurring/data/local_recurring_service.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../data/default_categories.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class FinancialSyncBanner extends ConsumerWidget {
  const FinancialSyncBanner({super.key, required this.kind});
  final String kind;
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final owner = ref.read(transactionOwnerProvider);
    final budgets =
        kind == 'budget' ? await LocalBudgetService().getAll() : null;
    final rules =
        kind == 'recurring' ? await LocalRecurringService().getAll() : null;
    if (!context.mounted || owner != ref.read(transactionOwnerProvider)) return;
    final count = budgets?.length ?? rules?.length ?? 0;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum registro antigo neste dispositivo.')));
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Importar dados deste dispositivo?'),
              content: Text(
                  '$count registros locais serão copiados para esta conta e sincronizados. Os originais serão preservados. Registros já existentes na conta não serão substituídos.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Importar'))
              ],
            ));
    if (!context.mounted ||
        confirmed != true ||
        owner != ref.read(transactionOwnerProvider)) {
      return;
    }
    try {
      if (budgets != null) {
        final notifier = ref.read(budgetListProvider.notifier);
        await notifier.service.synchronize();
        final existing = (await notifier.service.getAll())
            .map((b) => categoryNameKey(b.category))
            .toSet();
        final knownIds = await notifier.service.store.knownIds();
        for (final row in budgets) {
          if (owner != ref.read(transactionOwnerProvider)) return;
          if (!knownIds.contains('category:${categoryNameKey(row.category)}') &&
              existing.add(categoryNameKey(row.category))) {
            await notifier.add(row);
          }
        }
        await notifier.synchronize();
      } else if (rules != null) {
        final notifier = ref.read(recurringListProvider.notifier);
        await notifier.service.synchronize();
        final existing = await notifier.service.store.knownIds();
        for (final row in rules) {
          if (owner != ref.read(transactionOwnerProvider)) return;
          if (existing.add(row.id)) await notifier.add(row);
        }
        final knownPayments = await notifier.service.payments.knownIds();
        final ruleIds =
            (await notifier.service.getAll()).map((r) => r.id).toSet();
        for (final row in await LocalRecurringService().legacyPayments()) {
          if (owner != ref.read(transactionOwnerProvider)) return;
          if (ruleIds.contains(row['rule_id']) &&
              knownPayments.add(row['id'] as String)) {
            await notifier.service.payments.save(row);
          }
        }
        await notifier.synchronize();
      }
      // Guest definitions are never silently attached to a signed-in account.
      final accountCategories =
          await ref.read(categoryServiceProvider).getAll();
      // Only associated record definitions need to be offered in the catalog.
      final associated = <CategoryItem>[
        ...?budgets?.map((b) => CategoryItem(
            name: b.category, icon: b.categoryIcon ?? '📦', type: 'expense')),
        ...?rules?.map((r) => CategoryItem(
            name: r.category, icon: r.categoryIcon ?? '📦', type: 'expense')),
      ];
      final known = {
        ...defaultCategories.map((c) => c.key),
        ...accountCategories.map((c) => c.key)
      };
      for (final item in associated) {
        if (owner != ref.read(transactionOwnerProvider)) return;
        if (known.add(item.key)) {
          await ref
              .read(categoryListProvider.notifier)
              .add(item.name, item.icon, item.type);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Importação salva. A sincronização continua automaticamente.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível concluir a importação. Os dados foram preservados; tente novamente.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(transactionOwnerProvider);
    final failed = ref.watch(financialSyncFailedProvider(kind));
    return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
              owner == null
                  ? 'Salvo neste dispositivo'
                  : failed
                      ? 'Envio pendente. Tente atualizar.'
                      : 'Sincronização automática da conta',
              style: Theme.of(context).textTheme.bodySmall),
          if (owner != null)
            TextButton(
                onPressed: () => _import(context, ref),
                child: const Text('Importar dados antigos')),
          IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (kind == 'budget') {
                  ref.read(budgetListProvider.notifier).synchronize();
                } else {
                  ref.read(recurringListProvider.notifier).synchronize();
                }
                ref.read(categoryListProvider.notifier).synchronize();
              }),
        ]);
  }
}
