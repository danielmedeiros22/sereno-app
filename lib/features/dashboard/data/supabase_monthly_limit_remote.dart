import 'package:supabase_flutter/supabase_flutter.dart';

import 'monthly_limit_service.dart';

class SupabaseMonthlyLimitRemote implements MonthlyLimitRemote {
  SupabaseMonthlyLimitRemote(this.client);

  final SupabaseClient client;

  void _checkOwner(String userId) {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('A conta mudou; sincronização interrompida');
    }
  }

  @override
  Future<double?> fetch(String userId) async {
    _checkOwner(userId);
    final row = await client
        .from('monthly_spending_limits')
        .select('amount')
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    _checkOwner(userId);
    return (row?['amount'] as num?)?.toDouble();
  }

  @override
  Future<void> save(String userId, double value) async {
    _checkOwner(userId);
    await client.from('monthly_spending_limits').upsert({
      'user_id': userId,
      'amount': value,
    }, onConflict: 'user_id').timeout(const Duration(seconds: 10));
    _checkOwner(userId);
  }
}
