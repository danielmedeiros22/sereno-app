class CategoryItem {
  final String name;
  final String icon;
  final String type;

  const CategoryItem(
      {required this.name, required this.icon, required this.type});

  String get key => '$type:${categoryNameKey(name)}';
  Map<String, dynamic> toJson() => {'name': name, 'icon': icon, 'type': type};
  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
      name: json['name'] as String,
      icon: json['icon'] as String,
      type: json['type'] as String);
}

String categoryNameKey(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

const defaultCategories = <CategoryItem>[
  CategoryItem(name: 'Alimentação', icon: '🍽️', type: 'expense'),
  CategoryItem(name: 'Mercado', icon: '🛒', type: 'expense'),
  CategoryItem(name: 'Transporte', icon: '🚗', type: 'expense'),
  CategoryItem(name: 'Moradia', icon: '🏠', type: 'expense'),
  CategoryItem(name: 'Saúde', icon: '💊', type: 'expense'),
  CategoryItem(name: 'Educação', icon: '📚', type: 'expense'),
  CategoryItem(name: 'Lazer', icon: '🎮', type: 'expense'),
  CategoryItem(name: 'Vestuário', icon: '👕', type: 'expense'),
  CategoryItem(name: 'Beleza', icon: '💅', type: 'expense'),
  CategoryItem(name: 'Assinaturas', icon: '📱', type: 'expense'),
  CategoryItem(name: 'Pets', icon: '🐾', type: 'expense'),
  CategoryItem(name: 'Presentes', icon: '🎁', type: 'expense'),
  CategoryItem(name: 'Impostos', icon: '🏛️', type: 'expense'),
  CategoryItem(name: 'Seguros', icon: '🛡️', type: 'expense'),
  CategoryItem(name: 'Outros', icon: '📦', type: 'expense'),
  CategoryItem(name: 'Salário', icon: '💰', type: 'income'),
  CategoryItem(name: 'Freelance', icon: '💻', type: 'income'),
  CategoryItem(name: 'Investimentos', icon: '📈', type: 'income'),
  CategoryItem(name: 'Vendas', icon: '🏷️', type: 'income'),
  CategoryItem(name: 'Presente recebido', icon: '🎀', type: 'income'),
  CategoryItem(name: 'Reembolso', icon: '🔄', type: 'income'),
  CategoryItem(name: 'Outros', icon: '💵', type: 'income'),
];
