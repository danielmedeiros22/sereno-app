import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../transactions/data/default_categories.dart';
import '../../data/budget_model.dart';
import '../providers/budget_provider.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _amountController = TextEditingController();
  CategoryItem? _selectedCategory;

  final _categories = defaultCategories.where((c) => c.type == 'expense').toList();

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um valor válido')),
      );
      return;
    }

    final budget = BudgetModel(
      category: _selectedCategory!.name,
      categoryIcon: _selectedCategory!.icon,
      limit: amount,
    );

    await ref.read(budgetListProvider.notifier).add(budget);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Novo orçamento'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Salvar',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Categoria', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final active = _selectedCategory?.name == cat.name;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary.withValues(alpha: 0.15) : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.primary : theme.colorScheme.outline,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          cat.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: active ? AppColors.primary : theme.colorScheme.onSurface,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Text('Teto mensal', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('R\$', style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '0,00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Se gastar mais que esse valor na categoria, o Sereno te avisa.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}