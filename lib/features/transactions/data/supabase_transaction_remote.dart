import 'package:supabase_flutter/supabase_flutter.dart';

import 'transaction_sync_service.dart';

class SupabaseTransactionRemote implements TransactionRemote {
  SupabaseTransactionRemote(this.client);
  final SupabaseClient client;

  void _checkOwner(String userId) {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('A conta mudou durante a sincronização');
    }
  }

  @override
  Future<void> save(String userId, Map<String, dynamic> entry) async {
    _checkOwner(userId);
    await client.from('account_transactions').upsert({
      'user_id': userId,
      'id': entry['id'],
      'payload': entry['payload'],
      'is_deleted': entry['is_deleted'],
    }, onConflict: 'user_id,id');
    _checkOwner(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String userId) async {
    final all = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 500) {
      _checkOwner(userId);
      final page = await client
          .from('account_transactions')
          .select('id,payload,is_deleted')
          .eq('user_id', userId)
          .order('id')
          .range(offset, offset + 499);
      _checkOwner(userId);
      all.addAll(page);
      if (page.length < 500) break;
    }
    return all;
  }
}
