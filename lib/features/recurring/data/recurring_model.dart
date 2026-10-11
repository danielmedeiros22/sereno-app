import 'package:uuid/uuid.dart';
import 'recurring_schedule.dart';

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
  final DateTime? firstDueDate;

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
    this.firstDueDate,
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
        if (firstDueDate != null)
          'firstDueDate': firstDueDate!.toIso8601String(),
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
      firstDueDate: json['firstDueDate'] == null
          ? null
          : DateTime.parse(json['firstDueDate']),
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
      firstDueDate: firstDueDate,
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
    final dates = relevantDueDates(this, DateTime.now(), 366);
    return dates.isNotEmpty
        ? dates.first
        : firstDueDate ?? calendarDay(DateTime.now());
  }

  bool get needsDueDate =>
      firstDueDate == null && frequency != RecurringFrequency.monthly;

  int get daysUntilDue {
    return calendarDifference(nextDueDate, DateTime.now());
  }

  RecurringStatus get status {
    final days = daysUntilDue;
    if (days < 0) return RecurringStatus.overdue;
    return RecurringStatus.pending;
  }
}
