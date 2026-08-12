import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.value?.session?.user ?? SupabaseService.currentUser;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController();
});

class AuthController {
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // No Web, usa OAuth redirect do Supabase (mais confiavel)
        await SupabaseService.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
      } else {
        // No mobile, usa google_sign_in + idToken
        final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
        final googleSignIn = GoogleSignIn(serverClientId: webClientId);
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw Exception('Falha ao obter idToken do Google');
        }

        await SupabaseService.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      }
    } catch (e, s) {
      debugPrint('Google sign-in error: $e\n$s');
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      if (kIsWeb) {
        await SupabaseService.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: Uri.base.origin,
        );
      } else {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final idToken = credential.identityToken;
        if (idToken == null) {
          throw Exception('Falha ao obter identityToken da Apple');
        }

        await SupabaseService.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
        );
      }
    } catch (e, s) {
      debugPrint('Apple sign-in error: $e\n$s');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await SupabaseService.auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
