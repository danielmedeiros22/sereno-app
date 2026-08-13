import 'package:uuid/uuid.dart';

enum RecurringFrequency { weekly, biweekly, monthly, yearly }

enum RecurringStatus { pending, paid, overdue }

class RecurringModel {
  final String id;
  final String name;
  final double amount;
  final String category;
  final String? categoryIcon;
  final RecurringFrequency frequency;
  final int dueDay;
  final bool active;
  final DateTime createdAt;

  RecurringModel({
    String? id,
    required this.name,
    required this.amount,
    required this.category,
    this.categoryIcon,
    required this.frequency,
    required this.dueDay,
    this.active = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'category': category,
        'categoryIcon': categoryIcon,
        'frequency': frequency.name,
        'dueDay': dueDay,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecurringModel.fromJson(Map<String, dynamic> json) {
    return RecurringModel(
      id: json['id'],
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      categoryIcon: json['categoryIcon'],
      frequency: RecurringFrequency.values.firstWhere(
        (f) => f.name == json['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      dueDay: json['dueDay'],
      active: json['active'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  RecurringModel copyWith({bool? active}) {
    return RecurringModel(
      id: id,
      name: name,
      amount: amount,
      category: category,
      categoryIcon: categoryIcon,
      frequency: frequency,
      dueDay: dueDay,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  String get frequencyLabel {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return 'Semanal';
      case RecurringFrequency.biweekly:
        return 'Quinzenal';
      case RecurringFrequency.monthly:
        return 'Mensal';
      case RecurringFrequency.yearly:
        return 'Anual';
    }
  }

  DateTime get nextDueDate {
    final now = DateTime.now();
    if (frequency == RecurringFrequency.monthly) {
      final thisMonth = DateTime(now.year, now.month, dueDay.clamp(1, 28));
      if (thisMonth.isAfter(now) || thisMonth.day == now.day) return thisMonth;
      return DateTime(now.year, now.month + 1, dueDay.clamp(1, 28));
    }
    if (frequency == RecurringFrequency.yearly) {
      final thisYear = DateTime(now.year, dueDay.clamp(1, 12), 1);
      if (thisYear.isAfter(now)) return thisYear;
      return DateTime(now.year + 1, dueDay.clamp(1, 12), 1);
    }
    return now;
  }

  int get daysUntilDue {
    return nextDueDate.difference(DateTime.now()).inDays;
  }

  RecurringStatus get status {
    final days = daysUntilDue;
    if (days < 0) return RecurringStatus.overdue;
    return RecurringStatus.pending;
  }
}