import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/presentation/providers/summary_period.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../dashboard/presentation/providers/monthly_limit_provider.dart';
import '../../data/notification_engine.dart';
import '../../data/notification_preferences.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  bool _saving = false, _refreshing = false;
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
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      ref.invalidate(notificationDateProvider);
      await Future.wait([
        ref.read(transactionListProvider.notifier).synchronize(),
        ref.read(monthlyLimitProvider.notifier).synchronize(),
        ref.read(budgetListProvider.notifier).synchronize(),
        ref.read(recurringListProvider.notifier).synchronize(),
      ]);
      if (mounted) ref.invalidate(notificationPaymentsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível atualizar. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _save(NotificationPreferences value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(notificationPreferencesProvider.notifier).save(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível salvar suas preferências. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(SerenoAlert alert) {
    if (alert.type == SerenoAlertType.monthly) {
      final now = ref.read(notificationDateProvider);
      ref.read(summaryPeriodTypeProvider.notifier).state =
          SummaryPeriodType.month;
      ref.read(selectedMonthProvider.notifier).state = now;
      context.go('/');
    } else {
      context.push(
          alert.type == SerenoAlertType.budget ? '/budget' : '/recurring');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(serenoAlertsProvider);
    final preferences = ref.watch(notificationPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações'), actions: [
        IconButton(
            tooltip: 'Atualizar alertas',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Seus alertas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Avisos dentro do Sereno, com base nos últimos dados disponíveis. Teto e orçamentos consideram o mês atual. Atualize para buscar alterações da conta.'),
        const SizedBox(height: 12),
        const Card(
          child: ExpansionTile(
            leading: Icon(Icons.info_outline),
            title: Text('Como funcionam os alertas'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'A central está ligada aos seus dados financeiros. Você pode acessá-la pelos Ajustes ou pelo sino no painel.'),
              SizedBox(height: 12),
              Text(
                  'Teto e orçamentos: avisam quando os gastos do mês atual alcançam o percentual escolhido nas preferências.'),
              SizedBox(height: 8),
              Text(
                  'Contas: mostram vencimentos próximos, no dia e em atraso, conforme a antecedência escolhida.'),
              SizedBox(height: 12),
              Text(
                  'Os avisos desaparecem quando os dados deixam de justificar o alerta. Por exemplo: ao marcar uma conta como paga, o aviso dela deixa de aparecer.'),
              SizedBox(height: 8),
              Text(
                  'Ao mudar dados em outro dispositivo, toque em Atualizar para buscar as alterações da conta. Esta central mostra avisos dentro do app; não envia notificações com ele fechado.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        alerts.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator())),
          error: (_, __) => Column(children: [
            const Text('Não foi possível carregar todos os dados dos alertas.'),
            TextButton(
                onPressed: () {
                  ref.invalidate(notificationPreferencesProvider);
                  ref.read(transactionListProvider.notifier).load();
                  ref.read(budgetListProvider.notifier).load();
                  ref.read(recurringListProvider.notifier).load();
                  _refresh();
                },
                child: const Text('Tentar novamente')),
          ]),
          data: (items) => items.isEmpty
              ? const Card(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child:
                          Text('Nenhum alerta ativo para suas preferências.')))
              : Column(children: [
                  for (final alert in items)
                    Card(
                        child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(
                          alert.type == SerenoAlertType.bill
                              ? Icons.event_outlined
                              : alert.type == SerenoAlertType.setup
                                  ? Icons.edit_calendar_outlined
                                  : Icons.warning_amber_rounded,
                          color: alert.priority == 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary),
                      title: Text(alert.title),
                      subtitle: Text(alert.message),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(alert),
                    ))
                ]),
        ),
        const SizedBox(height: 24),
        preferences.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (prefs) => Card(
                    child: Column(children: [
                  const ListTile(
                      title: Text('Preferências'),
                      subtitle: Text(
                          'Salvas neste dispositivo, separadas por conta. Não enviam notificações com o app fechado.')),
                  SwitchListTile(
                      title: const Text('Teto mensal'),
                      value: prefs.monthly,
                      onChanged: _saving
                          ? null
                          : (v) => _save(prefs.copyWith(monthly: v))),
                  SwitchListTile(
                      title: const Text('Orçamentos por categoria'),
                      value: prefs.budgets,
                      onChanged: _saving
                          ? null
                          : (v) => _save(prefs.copyWith(budgets: v))),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          key: ValueKey('threshold:${prefs.threshold}'),
                          initialValue: prefs.threshold,
                          decoration: const InputDecoration(
                              labelText: 'Avisar a partir de'),
                          items: [
                            for (final percent in [50, 75, 90, 100])
                              DropdownMenuItem(
                                  value: percent,
                                  child: Text('$percent% do teto'))
                          ],
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v != null) {
                                    _save(prefs.copyWith(threshold: v));
                                  }
                                })),
                  SwitchListTile(
                      title: const Text('Contas futuras e atrasadas'),
                      value: prefs.bills,
                      onChanged: _saving
                          ? null
                          : (v) => _save(prefs.copyWith(bills: v))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          key: ValueKey('days:${prefs.daysBefore}'),
                          initialValue: prefs.daysBefore,
                          decoration: const InputDecoration(
                              labelText: 'Antecedência do lembrete'),
                          items: [
                            for (final days in [0, 1, 3, 7, 14])
                              DropdownMenuItem(
                                  value: days,
                                  child: Text(days == 0
                                      ? 'No dia do vencimento'
                                      : '$days dia${days == 1 ? '' : 's'} antes'))
                          ],
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v != null) {
                                    _save(prefs.copyWith(daysBefore: v));
                                  }
                                })),
                ]))),
      ]),
    );
  }
}
