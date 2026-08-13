import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../services/notifications/web_notification_service.dart';
import '../../../features/recurring/data/local_recurring_service.dart';
import '../../../features/recurring/data/recurring_model.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'warning', 'overdue', 'info'
  final DateTime createdAt;
  bool dismissed;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    DateTime? createdAt,
    this.dismissed = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

class NotificationService {
  final List<AppNotification> _notifications = [];
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final _recurringService = LocalRecurringService();
  final _webNotifications = WebNotificationService();

  Stream<List<AppNotification>> get stream => _controller.stream;
  List<AppNotification> get active => _notifications.where((n) => !n.dismissed).toList();

  Future<void> initialize() async {
    await _webNotifications.requestPermission();
  }

  Future<void> checkRecurringBills() async {
    _notifications.clear();

    final bills = await _recurringService.getAll();
    final paidIds = await _recurringService.getPaidIds(_recurringService.currentMonthKey());

    for (final bill in bills) {
      if (!bill.active) continue;
      if (paidIds.contains(bill.id)) continue;

      final days = bill.daysUntilDue;

      if (days < 0) {
        final notification = AppNotification(
          id: 'overdue_${bill.id}',
          title: '${bill.name} atrasada',
          body: 'Venceu há ${-days} dia${days == -1 ? "" : "s"} — R\$ ${bill.amount.toStringAsFixed(2)}',
          type: 'overdue',
        );
        _notifications.add(notification);
        _webNotifications.show(notification.title, notification.body);
      } else if (days == 0) {
        final notification = AppNotification(
          id: 'today_${bill.id}',
          title: '${bill.name} vence hoje',
          body: 'R\$ ${bill.amount.toStringAsFixed(2)} — não esqueça de pagar',
          type: 'warning',
        );
        _notifications.add(notification);
        _webNotifications.show(notification.title, notification.body);
      } else if (days <= 3) {
        final notification = AppNotification(
          id: 'soon_${bill.id}',
          title: '${bill.name} vence em $days dia${days == 1 ? "" : "s"}',
          body: 'R\$ ${bill.amount.toStringAsFixed(2)}',
          type: 'info',
        );
        _notifications.add(notification);
      }
    }

    _controller.add(active);
  }

  void dismiss(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].dismissed = true;
      _controller.add(active);
    }
  }

  void dismissAll() {
    for (final n in _notifications) {
      n.dismissed = true;
    }
    _controller.add(active);
  }

  void dispose() {
    _controller.close();
  }
}