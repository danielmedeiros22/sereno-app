import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/termometro_orb.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Valores mock — serão substituídos por Provider real depois
  double _spent = 1120;
  double _limit = 3500;

  double get _percent => (_spent / _limit) * 100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // Space switcher (mock)
                  _spaceSwitcher(theme),
                  const SizedBox(height: 24),

                  // Saudação + orbe
                  Text(
                    'Olá, ${user?.userMetadata?['full_name']?.split(' ').first ?? 'você'} 👋',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),

                  // Balance card com a orbe pequena ao lado
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SALDO ATUAL',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currency.format(5840.20),
                              style: theme.textTheme.displaySmall,
                            ),
                          ],
                        ),
                      ),
                      // Orbe pequena — tap abre a tela de limites
                      GestureDetector(
                        onTap: _openLimitsSheet,
                        child: Column(
                          children: [
                            TermometroOrb(percent: _percent, size: 72, showFace: true),
                            const SizedBox(height: 4),
                            Text(
                              '${_percent.toStringAsFixed(0)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.riskFor(_percent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Cards de fluxo
                  Row(
                    children: [
                      Expanded(child: _flowCard(theme, 'Entradas', 7000, AppColors.income, true)),
                      const SizedBox(width: 12),
                      Expanded(child: _flowCard(theme, 'Saídas', 1159, AppColors.expense, false)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Placeholder — próximos recursos
                  _placeholderCard(
                    theme,
                    'Últimas movimentações',
                    'Aparecem aqui conforme você registrar.',
                  ),
                  const SizedBox(height: 12),
                  _placeholderCard(
                    theme,
                    'Orçamento do mês',
                    'Defina tetos por categoria em Meus Limites.',
                  ),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: abrir formulário de nova transação
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Formulário de nova movimentação — em breve')),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _spaceSwitcher(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('👤', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pessoal', style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                Text(
                  'Seu espaço padrão',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.expand_more, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _flowCard(ThemeData theme, String label, double value, Color color, bool isIncome) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            currency.format(value),
            style: theme.textTheme.titleLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCard(ThemeData theme, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  void _openLimitsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LimitsSheet(
        currentLimit: _limit,
        currentSpent: _spent,
        onChanged: (newLimit) => setState(() => _limit = newLimit),
      ),
    );
  }
}

/// Bottom sheet com o slider do Termômetro
class _LimitsSheet extends StatefulWidget {
  const _LimitsSheet({
    required this.currentLimit,
    required this.currentSpent,
    required this.onChanged,
  });

  final double currentLimit;
  final double currentSpent;
  final ValueChanged<double> onChanged;

  @override
  State<_LimitsSheet> createState() => _LimitsSheetState();
}

class _LimitsSheetState extends State<_LimitsSheet> {
  late double _limit;
  double _step = 100;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _limit = widget.currentLimit;
    _textController = TextEditingController(text: _limit.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  double get _percent => (widget.currentSpent / _limit) * 100;

  void _updateLimit(double value) {
    setState(() {
      _limit = value.clamp(500, 10000);
      _textController.text = _limit.toStringAsFixed(0);
    });
    widget.onChanged(_limit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.riskFor(_percent);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Meus limites', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 24),

          // Orbe grande
          Center(child: TermometroOrb(percent: _percent, size: 140)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AppColors.moodFor(_percent),
              style: theme.textTheme.headlineMedium?.copyWith(color: color),
            ),
          ),
          Center(
            child: Text(
              '${_percent.toStringAsFixed(0)}% do teto usado',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),

          // Header do valor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TETO MENSAL', style: theme.textTheme.labelSmall),
                  Text('Gasto geral', style: theme.textTheme.titleMedium),
                ],
              ),
              // Valor editável
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.headlineLarge?.copyWith(color: color),
                  decoration: const InputDecoration(
                    prefixText: 'R\$ ',
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) _updateLimit(parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toggle de precisão
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PRECISÃO', style: theme.textTheme.labelSmall),
              _precisionToggle(theme, color),
            ],
          ),
          const SizedBox(height: 8),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: theme.colorScheme.outline,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 8,
            ),
            child: Slider(
              min: 500,
              max: 10000,
              divisions: (9500 / _step).round(),
              value: _limit.clamp(500, 10000),
              onChanged: _updateLimit,
            ),
          ),

          // Botões +/- pra ajuste fino
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Ajuste fino: ', style: theme.textTheme.labelSmall),
              const SizedBox(width: 8),
              _fineBtn(theme, '−', () => _updateLimit(_limit - 1), color),
              const SizedBox(width: 6),
              _fineBtn(theme, '+', () => _updateLimit(_limit + 1), color),
            ],
          ),
          const SizedBox(height: 20),

          // Gasto atual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gasto atual', style: theme.textTheme.bodySmall),
              Text(
                currency.format(widget.currentSpent),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_percent / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: theme.colorScheme.outline,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _precisionToggle(ThemeData theme, Color activeColor) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(10, activeColor, theme),
          _stepBtn(100, activeColor, theme),
        ],
      ),
    );
  }

  Widget _stepBtn(double step, Color activeColor, ThemeData theme) {
    final active = _step == step;
    return GestureDetector(
      onTap: () => setState(() => _step = step),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'R\$ ${step.toStringAsFixed(0)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: active ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _fineBtn(ThemeData theme, String label, VoidCallback onTap, Color activeColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: theme.textTheme.titleMedium),
      ),
    );
  }
}
