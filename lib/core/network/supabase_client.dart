import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper de conveniência para o Supabase client.
///
/// Uso: `SupabaseService.client` em qualquer lugar após `Supabase.initialize`.
class SupabaseService {
  const SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  static Session? get currentSession => auth.currentSession;
  static User? get currentUser => auth.currentUser;

  static bool get isAuthenticated => currentSession != null;

  /// Stream do estado de autenticação — para reagir a login/logout globalmente.
  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;
}
