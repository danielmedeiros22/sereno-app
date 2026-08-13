import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/guest_service.dart';
import '../../../../core/services/sync/sync_indicator.dart';
import '../../../../core/services/notifications/notification_banner.dart';
import '../../../../core/services/notifications/notification_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/data/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/presentation/screens/transaction_form_screen.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../widgets/guest_banner.dart';
import '../widgets/termometro_orb.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double _limit = 3500;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
  }

  void _checkNotifications() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(notificationServiceProvider);
      service.initialize();
      service.checkRecurringBills();
    });
  }

  void _openForm() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);
    final txList = ref.watch(transactionListProvider);
    final totals = ref.watch(monthTotalsProvider);

    final displayName = isGuest ? 'Visitante' : user?.userMetadata?['full_name']?.split(' ').first ?? 'você';
    final income = totals.value?['income'] ?? 0;
    final expense = totals.value?['expense'] ?? 0;
    final balance = income - expense;
    final percent = _limit > 0 ? (expense / _limit) * 100 : 0.0;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              actions: [
                IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  if (isGuest) ...[const GuestBanner(), const SizedBox(height: 16)],
                  if (!isGuest) ...[
                    const SyncIndicator(),
                    const SizedBox(height: 8),
                  ],
                  const NotificationBanner(),
                  _buildSpaceSwitcher(theme),
                  const SizedBox(height: 24),
                  Text('Olá, $displayName 👋', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SALDO ATUAL', style: theme.textTheme.labelSmall),
                            const SizedBox(height: 4),
                            Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(balance), style: theme.textTheme.displaySmall?.copyWith(color: balance >= 0 ? null : AppColors.expense)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openLimitsSheet(expense),
                        child: Column(
                          children: [
                            TermometroOrb(percent: percent, size: 72, showFace: true),
                            const SizedBox(height: 4),
                            Text('${percent.toStringAsFixed(0)}%', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.riskFor(percent))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildFlowCard(theme, 'Entradas', income, AppColors.income, true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildFlowCard(theme, 'Saídas', expense, AppColors.expense, false)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Últimas movimentações', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
            txList.when(
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Erro: $e'))),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outline)),
                      child: Column(children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text('Nenhuma movimentação ainda', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      ]),
                    ),
                  );
                }

                final grouped = <String, List<TransactionModel>>{};
                for (final tx in transactions) {
                  final key = _dateLabel(tx.date);
                  grouped.putIfAbsent(key, () => []).add(tx);
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = grouped.entries.toList()[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(entry.key, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)))),
                            ...entry.value.map((tx) => TransactionTile(transaction: tx, onDismissed: () {
                              ref.read(transactionListProvider.notifier).remove(tx.id);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tx.category} removida')));
                            })),
                          ],
                        );
                      },
                      childCount: grouped.length,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSpaceSwitcher(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outline)),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('👤', style: TextStyle(fontSize: 18)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pessoal', style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)), Text('Seu espaço padrão', style: theme.textTheme.bodySmall)])),
          Icon(Icons.expand_more, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildFlowCard(ThemeData theme, String label, double value, Color color, bool isIncome) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.colorScheme.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 16)),
        const SizedBox(height: 10),
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value), style: theme.textTheme.titleLarge?.copyWith(color: color)),
      ]),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Hoje';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Ontem';
    return DateFormat("d 'de' MMMM", 'pt_BR').format(date);
  }

  void _openLimitsSheet(double spent) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _LimitsSheet(currentLimit: _limit, currentSpent: spent, onChanged: (newLimit) => setState(() => _limit = newLimit)));
  }
}

class _LimitsSheet extends StatefulWidget {
  const _LimitsSheet({required this.currentLimit, required this.currentSpent, required this.onChanged});
  final double currentLimit;
  final double currentSpent;
  final ValueChanged<double> onChanged;

  @override
  State<_LimitsSheet> createState() => _LimitsSheetState();
}

class _LimitsSheetState extends State<_LimitsSheet> {
  late double _limit;
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

  double get _percent => _limit > 0 ? (widget.currentSpent / _limit) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.riskFor(_percent);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)))),
        Text('Meus limites', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 24),
        Center(child: TermometroOrb(percent: _percent, size: 140)),
        const SizedBox(height: 16),
        Center(child: Text(AppColors.moodFor(_percent), style: theme.textTheme.headlineMedium?.copyWith(color: color))),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('TETO MENSAL', style: theme.textTheme.labelSmall),
          SizedBox(width: 140, child: TextField(controller: _textController, keyboardType: TextInputType.number, textAlign: TextAlign.right, style: theme.textTheme.headlineLarge?.copyWith(color: color), decoration: const InputDecoration(prefixText: 'R\$ ', border: InputBorder.none), onSubmitted: (v) { final p = double.tryParse(v); if (p != null) { setState(() { _limit = p.clamp(100, 50000); }); widget.onChanged(_limit); } })),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Gasto atual', style: theme.textTheme.bodySmall), Text(currency.format(widget.currentSpent), style: theme.textTheme.titleMedium)]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_percent / 100).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: theme.colorScheme.outline, valueColor: AlwaysStoppedAnimation(color))),
      ]),
    );
  }
}