import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../transactions/data/default_categories.dart';
import '../../../transactions/presentation/widgets/category_picker.dart';
import '../../data/recurring_model.dart';
import '../../data/recurring_schedule.dart';
import '../providers/recurring_provider.dart';

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.rule});
  final RecurringModel? rule;

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  int _dueDay = DateTime.now().day;
  CategoryItem? _selectedCategory;
  DateTime? _firstDueDate;

  final _categories =
      defaultCategories.where((c) => c.type == 'expense').toList();

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.first;
    final rule = widget.rule;
    _firstDueDate = rule?.firstDueDate ??
        (rule == null ? calendarDay(DateTime.now()) : null);
    if (rule != null) {
      _nameController.text = rule.name;
      _amountController.text =
          rule.amount.toStringAsFixed(2).replaceAll('.', ',');
      _frequency = rule.frequency;
      _dueDay = rule.dueDay.clamp(1, 31);
      _selectedCategory = CategoryItem(
          name: rule.category,
          icon: rule.categoryIcon ?? '📦',
          type: 'expense');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_frequency != RecurringFrequency.monthly && _firstDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Defina o primeiro vencimento para esta periodicidade.')));
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome da conta')),
      );
      return;
    }

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

    final rule = RecurringModel(
      id: widget.rule?.id,
      createdAt: widget.rule?.createdAt,
      active: widget.rule?.active ?? true,
      firstDueDate: _firstDueDate,
      name: _nameController.text.trim(),
      amount: amount,
      category: _selectedCategory!.name,
      categoryIcon: _selectedCategory!.icon,
      frequency: _frequency,
      dueDay: _dueDay,
    );

    await ref.read(recurringListProvider.notifier).add(rule);
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
        title: Text(widget.rule == null
            ? 'Nova conta recorrente'
            : 'Editar conta recorrente'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Salvar',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nome da conta',
                hintText: 'Ex: Aluguel, Netflix, Internet',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(height: 24),
            // Valor
            Row(
              children: [
                Text('R\$',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: AppColors.expense)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                    ],
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.expense, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '0,00',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Frequência
            Text('Frequência', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RecurringFrequency.values.map((freq) {
                final active = _frequency == freq;
                final label = RecurringModel(
                  name: '',
                  amount: 0,
                  category: '',
                  frequency: freq,
                  dueDay: 1,
                ).frequencyLabel;

                return GestureDetector(
                  onTap: () => setState(() => _frequency = freq),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : theme.colorScheme.outline,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: active
                            ? AppColors.primary
                            : theme.colorScheme.onSurface,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            // Dia do vencimento
            Text('Dia do vencimento', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text('Dia', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _dueDay,
                        isExpanded: true,
                        alignment: AlignmentDirectional.centerEnd,
                        items: List.generate(31, (i) => i + 1)
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text('$d', textAlign: TextAlign.right),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _dueDay = val;
                              if (_firstDueDate != null) {
                                _firstDueDate = clampedDay(_firstDueDate!.year,
                                    _firstDueDate!.month, val);
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Categoria
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Primeiro vencimento'),
                subtitle: Text(_firstDueDate == null
                    ? 'Definir data para os lembretes'
                    : DateFormat('dd/MM/yyyy').format(_firstDueDate!)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final initial = _firstDueDate ?? DateTime.now();
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(initial.year - 10),
                      lastDate: DateTime(initial.year + 10, 12, 31));
                  if (picked != null && mounted) {
                    setState(() {
                      _firstDueDate = picked;
                      _dueDay = picked.day;
                    });
                  }
                }),
            const SizedBox(height: 12),
            Text('Categoria', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            CategoryPicker(
                type: 'expense',
                selected: _selectedCategory,
                onChanged: (category) =>
                    setState(() => _selectedCategory = category)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
