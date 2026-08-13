import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/recurring_model.dart';
import '../providers/recurring_provider.dart';
import 'recurring_form_screen.dart';

class RecurringListScreen extends ConsumerWidget {
  const RecurringListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recurringList = ref.watch(recurringListProvider);
    final paidIds = ref.watch(paidIdsProvider);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final service = ref.read(localRecurringServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas recorrentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringFormScreen()),
            ),
          ),
        ],
      ),
      body: recurringList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat, size: 64,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('Nenhuma conta recorrente',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    Text('Adicione aluguel, internet, assinaturas...',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecurringFormScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar conta'),
                    ),
                  ],
                ),
              ),
            );
          }

          final paid = paidIds.value ?? {};
          final monthKey = service.currentMonthKey();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isPaid = paid.contains(item.id);
              final daysLeft = item.daysUntilDue;
              final isOverdue = daysLeft < 0 && !isPaid;

              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                onDismissed: (_) {
                  ref.read(recurringListProvider.notifier).remove(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item.name} removida')),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOverdue
                          ? AppColors.expense.withValues(alpha: 0.4)
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox pagar
                      GestureDetector(
                        onTap: () async {
                          if (isPaid) {
                            await service.unmarkPaid(item.id, monthKey);
                          } else {
                            await service.markPaid(item.id, monthKey);
                          }
                          ref.invalidate(paidIdsProvider);
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppColors.income.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPaid ? AppColors.income : theme.colorScheme.outline,
                              width: 2,
                            ),
                          ),
                          child: isPaid
                              ? const Icon(Icons.check, size: 16, color: AppColors.income)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Ícone
                      Text(item.categoryIcon ?? '📦', style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                decoration: isPaid ? TextDecoration.lineThrough : null,
                                color: isPaid
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPaid
                                  ? 'Paga este mês'
                                  : isOverdue
                                      ? 'Atrasada ${-daysLeft} dia${daysLeft == -1 ? "" : "s"}'
                                      : daysLeft == 0
                                          ? 'Vence hoje'
                                          : 'Vence em $daysLeft dia${daysLeft == 1 ? "" : "s"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isPaid
                                    ? AppColors.income
                                    : isOverdue
                                        ? AppColors.expense
                                        : daysLeft <= 3
                                            ? AppColors.alert
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Valor
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(item.amount),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isPaid
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                  : AppColors.expense,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.frequencyLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}