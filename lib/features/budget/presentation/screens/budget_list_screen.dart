import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/budget_model.dart';
import '../providers/budget_provider.dart';
import 'budget_form_screen.dart';

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgetList = ref.watch(budgetListProvider);
    final categorySpent = ref.watch(categorySpentProvider);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamento por categoria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetFormScreen()),
            ),
          ),
        ],
      ),
      body: budgetList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_outline, size: 64,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('Nenhum orçamento definido',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    Text('Defina tetos mensais por categoria pra controlar seus gastos.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BudgetFormScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Definir orçamento'),
                    ),
                  ],
                ),
              ),
            );
          }

          final spent = categorySpent.value ?? {};

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final catSpent = spent[budget.category] ?? 0;
              final percent = budget.limit > 0 ? (catSpent / budget.limit) * 100 : 0.0;
              final color = AppColors.riskFor(percent);

              return Dismissible(
                key: Key(budget.id),
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
                  ref.read(budgetListProvider.notifier).remove(budget.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Orçamento de ${budget.category} removido')),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(budget.categoryIcon ?? '📦', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(budget.category, style: theme.textTheme.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  '${currency.format(catSpent)} de ${currency.format(budget.limit)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (percent / 100).clamp(0, 1).toDouble(),
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.outline,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
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