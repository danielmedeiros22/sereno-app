import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/guest_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListener = RouterRefreshListener(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListener,
    redirect: (context, state) {
      final isAuthed = ref.read(isAuthenticatedProvider);
      final isGuest = ref.read(isGuestProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/welcome' || loc == '/login';

      if (!isAuthed && !isGuest && !isAuthRoute) return '/welcome';
      if ((isAuthed || isGuest) && isAuthRoute) return '/';
      return null;
    },
    errorBuilder: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GoRouter.of(context).go('/');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
});

class RouterRefreshListener extends ChangeNotifier {
  RouterRefreshListener(this.ref) {
    authSub = ref.listen<AsyncValue<AuthState>>(
      authStateProvider,
      (previous, next) {
        notifyListeners();
      },
    );
    guestSub = ref.listen<bool>(
      isGuestProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }

  final Ref ref;
  late final ProviderSubscription authSub;
  late final ProviderSubscription guestSub;

  @override
  void dispose() {
    authSub.close();
    guestSub.close();
    super.dispose();
  }
}