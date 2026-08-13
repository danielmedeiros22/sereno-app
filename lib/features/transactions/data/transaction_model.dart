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
  final double? latitude;
  final double? longitude;
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
    this.latitude,
    this.longitude,
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
        'latitude': latitude,
        'longitude': longitude,
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
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get hasLocation => latitude != null && longitude != null;
}