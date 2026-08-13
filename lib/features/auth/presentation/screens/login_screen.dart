import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/guest_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/oauth_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  Future<void> _signInGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authControllerProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _signInApple() async {
    setState(() => _isAppleLoading = true);
    try {
      await ref.read(authControllerProvider).signInWithApple();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final guestService = ref.read(guestServiceProvider);
    await guestService.enableGuestMode();
    ref.read(isGuestProvider.notifier).state = true;
    if (mounted) context.go('/');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao entrar: $msg')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showApple = !kIsMobileAndroid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Entre no Sereno',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Sua carteira, seus espaços, seu ritmo. '
                'Escolha como quer entrar.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              GoogleSignInButton(
                onPressed: _signInGoogle,
                isLoading: _isGoogleLoading,
              ),
              if (showApple) ...[
                const SizedBox(height: 12),
                AppleSignInButton(
                  onPressed: _signInApple,
                  isLoading: _isAppleLoading,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: theme.colorScheme.outline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ou',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.colorScheme.outline)),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _continueAsGuest,
                icon: const Icon(Icons.explore_outlined, size: 20),
                label: const Text('Continuar sem conta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seus dados ficam salvos neste dispositivo. '
                'Crie uma conta depois pra sincronizar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ao continuar, você concorda com os termos de uso '
                'e a política de privacidade.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get kIsMobileAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }
}