class CategoryItem {
  final String name;
  final String icon;
  final String type;

  const CategoryItem({required this.name, required this.icon, required this.type});
}

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
