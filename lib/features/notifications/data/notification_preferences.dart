import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences(
      {this.monthly = true,
      this.budgets = true,
      this.bills = true,
      this.threshold = 90,
      this.daysBefore = 3});
  final bool monthly, budgets, bills;
  final int threshold, daysBefore;
  NotificationPreferences copyWith(
          {bool? monthly,
          bool? budgets,
          bool? bills,
          int? threshold,
          int? daysBefore}) =>
      NotificationPreferences(
          monthly: monthly ?? this.monthly,
          budgets: budgets ?? this.budgets,
          bills: bills ?? this.bills,
          threshold: threshold ?? this.threshold,
          daysBefore: daysBefore ?? this.daysBefore);
  Map<String, dynamic> toJson() => {
        'monthly': monthly,
        'budgets': budgets,
        'bills': bills,
        'threshold': threshold,
        'daysBefore': daysBefore
      };
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
          monthly: json['monthly'] != false,
          budgets: json['budgets'] != false,
          bills: json['bills'] != false,
          threshold: [50, 75, 90, 100].contains(json['threshold'])
              ? json['threshold'] as int
              : 90,
          daysBefore: [0, 1, 3, 7, 14].contains(json['daysBefore'])
              ? json['daysBefore'] as int
              : 3);
}

class NotificationPreferencesService {
  NotificationPreferencesService(this.owner);
  final String? owner;
  String get key =>
      'notification_preferences:v1:${owner == null ? 'guest' : 'user:$owner'}';
  Future<NotificationPreferences> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null
        ? const NotificationPreferences()
        : NotificationPreferences.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<void> save(NotificationPreferences value) async {
    if (!await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(value.toJson()))) {
      throw StateError('Não foi possível salvar as preferências.');
    }
  }
}
