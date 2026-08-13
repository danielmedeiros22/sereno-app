import 'package:uuid/uuid.dart';

class BudgetModel {
  final String id;
  final String category;
  final String? categoryIcon;
  final double limit;
  final DateTime createdAt;

  BudgetModel({
    String? id,
    required this.category,
    this.categoryIcon,
    required this.limit,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'categoryIcon': categoryIcon,
        'limit': limit,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'],
      category: json['category'],
      categoryIcon: json['categoryIcon'],
      limit: (json['limit'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}