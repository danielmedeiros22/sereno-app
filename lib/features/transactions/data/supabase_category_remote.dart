import 'package:supabase_flutter/supabase_flutter.dart';
import 'category_service.dart';
import 'default_categories.dart';

class SupabaseCategoryRemote implements CategoryRemote {
  SupabaseCategoryRemote(this.client);
  final SupabaseClient client;
  void _check(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('A conta mudou durante a sincronização.');
    }
  }

  @override
  Future<void> save(String owner, CategoryItem category) async {
    _check(owner);
    await client.from('account_categories').upsert({
      'user_id': owner,
      'name_key': categoryNameKey(category.name),
      ...category.toJson(),
    }, onConflict: 'user_id,type,name_key');
    _check(owner);
  }

  @override
  Future<List<CategoryItem>> fetch(String owner) async {
    final all = <CategoryItem>[];
    for (var offset = 0;; offset += 500) {
      _check(owner);
      final rows = await client
          .from('account_categories')
          .select('name,icon,type')
          .eq('user_id', owner)
          .order('type')
          .order('name_key')
          .range(offset, offset + 499);
      _check(owner);
      all.addAll(rows.map(CategoryItem.fromJson));
      if (rows.length < 500) break;
    }
    return all;
  }
}
