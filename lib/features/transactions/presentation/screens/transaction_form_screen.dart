import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../data/default_categories.dart';
import '../../data/transaction_model.dart';
import '../providers/transaction_provider.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  CategoryItem? _selectedCategory;

  final _locationService = LocationService();
  LocationResult? _location;
  bool _loadingLocation = true;
  bool _locationEnabled = true;

  List<CategoryItem> get _filteredCategories =>
      defaultCategories.where((c) => c.type == _type).toList();

  @override
  void initState() {
    super.initState();
    _selectedCategory = _filteredCategories.first;
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _loadingLocation = true);
    final result = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _location = result;
        _loadingLocation = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color get _activeColor =>
      _type == 'income' ? AppColors.income : AppColors.expense;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
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

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }

    final tx = TransactionModel(
      type: _type,
      amount: amount,
      category: _selectedCategory!.name,
      categoryIcon: _selectedCategory!.icon,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      date: _date,
      location: _locationEnabled ? _location?.address : null,
      latitude: _locationEnabled ? _location?.latitude : null,
      longitude: _locationEnabled ? _location?.longitude : null,
    );

    await ref.read(transactionListProvider.notifier).add(tx);
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
        title: const Text('Nova movimentação'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Salvar',
                style: TextStyle(
                    color: _activeColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTypeToggle(theme),
            const SizedBox(height: 32),
            _buildAmountField(theme),
            const SizedBox(height: 28),
            _buildDatePicker(theme),
            const SizedBox(height: 16),
            _buildLocationCard(theme),
            const SizedBox(height: 28),
            Text('Categoria', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            _buildCategoryGrid(theme),
            const SizedBox(height: 28),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Ex: Almoço no restaurante',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(ThemeData theme) {
    if (!_locationEnabled) {
      return InkWell(
        onTap: () {
          setState(() => _locationEnabled = true);
          _fetchLocation();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined,
                  size: 20,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(width: 12),
              Text('Localização desativada',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4))),
              const Spacer(),
              Text('Ativar',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: _activeColor)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            _loadingLocation
                ? Icons.my_location
                : Icons.location_on_outlined,
            size: 20,
            color: _location != null
                ? _activeColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _loadingLocation
                ? Row(children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _activeColor)),
                    const SizedBox(width: 8),
                    Text('Buscando localização...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5))),
                  ])
                : _location != null
                    ? Text(
                        _location!.address ??
                            '${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text('Localização indisponível',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4))),
          ),
          IconButton(
            onPressed: () => setState(() {
              _locationEnabled = false;
              _location = null;
            }),
            icon: Icon(Icons.close,
                size: 16,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
              child: _typeButton(
                  'expense', 'Saída', Icons.arrow_downward, theme)),
          const SizedBox(width: 4),
          Expanded(
              child: _typeButton(
                  'income', 'Entrada', Icons.arrow_upward, theme)),
        ],
      ),
    );
  }

  Widget _typeButton(
      String type, String label, IconData icon, ThemeData theme) {
    final active = _type == type;
    final color = type == 'income' ? AppColors.income : AppColors.expense;

    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
          _selectedCategory = _filteredCategories.first;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:
              active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: color.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: active
                    ? color
                    : theme.colorScheme.onSurface
                        .withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: active
                    ? color
                    : theme.colorScheme.onSurface
                        .withValues(alpha: 0.4),
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _type == 'income' ? 'Quanto entrou?' : 'Quanto gastou?',
          style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('R\$',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: _activeColor)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[\d.,]')),
                ],
                style: theme.textTheme.displayMedium?.copyWith(
                    color: _activeColor,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0,00',
                  hintStyle: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.15)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker(ThemeData theme) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 20, color: _activeColor),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    isToday
                        ? 'Hoje'
                        : DateFormat('dd/MM/yyyy').format(_date),
                    style: theme.textTheme.bodyLarge)),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _filteredCategories.map((cat) {
        final active = _selectedCategory?.name == cat.name;
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? _activeColor.withValues(alpha: 0.15)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? _activeColor
                    : theme.colorScheme.outline,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.icon,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  cat.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: active
                        ? _activeColor
                        : theme.colorScheme.onSurface,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}