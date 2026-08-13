import 'package:uuid/uuid.dart';

class TransactionModel {
  final String id;
  final String type;
  final double amount;
  final String category;
  final String? categoryIcon;
  final String? description;
  final DateTime date;
  final String? location;
  final DateTime createdAt;

  TransactionModel({
    String? id,
    required this.type,
    required this.amount,
    required this.category,
    this.categoryIcon,
    this.description,
    required this.date,
    this.location,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'categoryIcon': categoryIcon,
        'description': description,
        'date': date.toIso8601String(),
        'location': location,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      type: json['type'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      categoryIcon: json['categoryIcon'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      location: json['location'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
}
