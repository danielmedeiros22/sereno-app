import 'package:intl/intl.dart';
import '../../budget/data/budget_model.dart';
import '../../recurring/data/recurring_model.dart';
import '../../recurring/data/recurring_schedule.dart';
import '../../transactions/data/default_categories.dart';
import '../../transactions/data/transaction_model.dart';
import 'notification_preferences.dart';

enum SerenoAlertType { monthly, budget, bill, setup }

class SerenoAlert {
  const SerenoAlert(
      this.id, this.type, this.title, this.message, this.priority);
  final String id, title, message;
  final SerenoAlertType type;
  final int priority;
}

List<SerenoAlert> buildSerenoAlerts(
    {required DateTime now,
    required List<TransactionModel> transactions,
    required double monthlyLimit,
    required List<BudgetModel> budgets,
    required List<RecurringModel> bills,
    required Map<String, Set<String>> paidByMonth,
    required NotificationPreferences preferences}) {
  final alerts = <SerenoAlert>[];
  final spent = <String, double>{};
  var total = 0.0;
  final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  for (final tx in transactions) {
    final date = tx.date.toLocal();
    if (!tx.isExpense || date.year != now.year || date.month != now.month) {
      continue;
    }
    total += tx.amount;
    spent.update(categoryNameKey(tx.category), (value) => value + tx.amount,
        ifAbsent: () => tx.amount);
  }
  void limitAlert(String id, SerenoAlertType type, String name, double expense,
      double limit) {
    if (!limit.isFinite || limit <= 0) return;
    final percent = expense / limit * 100;
    if (percent < preferences.threshold) return;
    final exceeded = percent > 100;
    alerts.add(SerenoAlert(
        id,
        type,
        exceeded
            ? '$name ultrapassado'
            : percent >= 100
                ? '$name atingido'
                : '$name perto do limite',
        '${percent.toStringAsFixed(0)}% utilizado: ${currency.format(expense)} de ${currency.format(limit)} neste mês.',
        percent >= 100 ? 0 : 2));
  }

  if (preferences.monthly) {
    limitAlert('monthly:${paymentMonth(now)}', SerenoAlertType.monthly,
        'Teto mensal', total, monthlyLimit);
  }
  if (preferences.budgets) {
    for (final budget in budgets) {
      limitAlert(
          'budget:${budget.id}:${paymentMonth(now)}',
          SerenoAlertType.budget,
          'Orçamento de ${budget.category}',
          spent[categoryNameKey(budget.category)] ?? 0,
          budget.limit);
    }
  }
  if (preferences.bills) {
    for (final bill in bills.where((bill) => bill.active)) {
      if (bill.firstDueDate == null &&
          bill.frequency != RecurringFrequency.monthly) {
        alerts.add(SerenoAlert(
            'setup:${bill.id}',
            SerenoAlertType.setup,
            'Defina a data de ${bill.name}',
            'Informe o primeiro vencimento em Contas recorrentes para receber lembretes precisos.',
            3));
        continue;
      }
      final unpaid = relevantDueDates(bill, now, preferences.daysBefore)
          .where((date) =>
              !(paidByMonth[paymentMonth(date)] ?? {}).contains(bill.id))
          .toList();
      if (unpaid.isEmpty) continue;
      final due = unpaid.first;
      final days = calendarDifference(due, now);
      final description = days < 0
          ? 'Está atrasada há ${-days} dia${days == -1 ? '' : 's'}'
          : days == 0
              ? 'Vence hoje'
              : 'Vence em $days dia${days == 1 ? '' : 's'}';
      alerts.add(SerenoAlert(
          'bill:${bill.id}:${DateFormat('yyyy-MM-dd').format(due)}',
          SerenoAlertType.bill,
          bill.name,
          '$description (${DateFormat('dd/MM/yyyy').format(due)}). Valor: ${currency.format(bill.amount)}.',
          days <= 0 ? 1 : 2));
    }
  }
  alerts.sort((a, b) {
    final order = a.priority.compareTo(b.priority);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return alerts;
}
