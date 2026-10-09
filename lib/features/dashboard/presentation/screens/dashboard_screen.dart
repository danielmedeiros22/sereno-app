import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/guest_service.dart';
import '../../../../core/services/sync/sync_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/data/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/presentation/screens/transaction_form_screen.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../../transactions/presentation/widgets/transaction_sync_banner.dart';
import '../widgets/guest_banner.dart';
import '../widgets/monthly_limit_sheet.dart';
import '../widgets/termometro_orb.dart';
import '../../data/monthly_limit_service.dart';
import '../providers/monthly_limit_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(monthlyLimitProvider.notifier).synchronize();
      ref.read(transactionListProvider.notifier).synchronize();
    }
  }

  Future<void> _saveLimit(double limit) =>
      ref.read(monthlyLimitProvider.notifier).save(limit);

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final owner = ref.read(transactionOwnerProvider);
    try {
      final transactions = ref.read(transactionListProvider.notifier);
      final monthlyLimit = ref.read(monthlyLimitProvider.notifier);
      await Future.wait([transactions.load(), monthlyLimit.ready]);
      await Future.wait([
        transactions.synchronize(),
        monthlyLimit.synchronize(),
      ]);
      if (!mounted || owner != ref.read(transactionOwnerProvider)) return;
      final transactionStatus = ref.read(transactionSyncStatusProvider);
      final limitState = ref.read(monthlyLimitProvider);
      final failed = transactionStatus == TransactionSyncStatus.failed ||
          ref.read(transactionListProvider).hasError ||
          limitState.hasError ||
          limitState.valueOrNull?.syncFailed == true;
      final syncing = transactionStatus == TransactionSyncStatus.syncing ||
          limitState.valueOrNull?.syncing == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failed
            ? 'Não foi possível atualizar tudo agora. Seus dados foram preservados.'
            : syncing
                ? 'A sincronização continua em andamento.'
                : owner == null
                    ? 'Informações locais atualizadas.'
                    : 'Informações atualizadas.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível atualizar agora. Tente novamente.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
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
    final limitState = ref.watch(monthlyLimitProvider);
    final limit = limitState.valueOrNull?.record.value ??
        MonthlyLimitService.defaultLimit;

    final displayName = isGuest
        ? 'Visitante'
        : user?.userMetadata?['full_name']?.split(' ').first ?? 'você';
    final income = totals.value?['income'] ?? 0;
    final expense = totals.value?['expense'] ?? 0;
    final balance = income - expense;
    final percent = limit > 0 ? (expense / limit) * 100 : 0.0;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              actions: [
                TextButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_refreshing ? 'Atualizando…' : 'Atualizar'),
                ),
                IconButton(
                    tooltip: 'Configurações',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings')),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  const TransactionSyncBanner(),
                  if (isGuest) ...[
                    const GuestBanner(),
                    const SizedBox(height: 16)
                  ],
                  if (!isGuest) ...[
                    const SyncIndicator(),
                    const SizedBox(height: 8),
                  ],
                  _buildSpaceSwitcher(theme),
                  const SizedBox(height: 24),
                  Text('Olá, $displayName 👋',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SALDO ATUAL',
                                style: theme.textTheme.labelSmall),
                            const SizedBox(height: 4),
                            Text(
                                NumberFormat.currency(
                                        locale: 'pt_BR', symbol: 'R\$')
                                    .format(balance),
                                style: theme.textTheme.displaySmall?.copyWith(
                                    color: balance >= 0
                                        ? null
                                        : AppColors.expense)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openLimitsSheet(expense),
                        child: Column(
                          children: [
                            TermometroOrb(
                                percent: percent, size: 72, showFace: true),
                            const SizedBox(height: 4),
                            Text('${percent.toStringAsFixed(0)}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.riskFor(percent))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: _buildFlowCard(theme, 'Entradas', income,
                              AppColors.income, true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildFlowCard(theme, 'Saídas', expense,
                              AppColors.expense, false)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Últimas movimentações',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
            txList.when(
              loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) =>
                  SliverToBoxAdapter(child: Center(child: Text('Erro: $e'))),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outline)),
                      child: Column(children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text('Nenhuma movimentação ainda',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
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
                            Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(entry.key,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4)))),
                            ...entry.value.map((tx) => TransactionTile(
                                transaction: tx,
                                onDismissed: () {
                                  ref
                                      .read(transactionListProvider.notifier)
                                      .remove(tx.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('${tx.category} removida')));
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
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline)),
      child: Row(
        children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 18)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Pessoal',
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                Text('Seu espaço padrão', style: theme.textTheme.bodySmall)
              ])),
          Icon(Icons.expand_more,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildFlowCard(
      ThemeData theme, String label, double value, Color color, bool isIncome) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                color: color, size: 16)),
        const SizedBox(height: 10),
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
            NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value),
            style: theme.textTheme.titleLarge?.copyWith(color: color)),
      ]),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Hoje';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Ontem';
    }
    return DateFormat("d 'de' MMMM", 'pt_BR').format(date);
  }

  void _openLimitsSheet(double spent) async {
    final controller = ref.read(monthlyLimitProvider.notifier);
    final owner = ref.read(monthlyLimitOwnerProvider);
    await controller.ready;
    if (!mounted) return;
    if (owner != ref.read(monthlyLimitOwnerProvider)) return;
    final record = ref.read(monthlyLimitProvider).valueOrNull?.record;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível carregar o teto mensal.')));
      return;
    }
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MonthlyLimitSheet(
            currentLimit: record.value,
            currentSpent: spent,
            owner: owner,
            onChanged: _saveLimit));
  }
}
