import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/services/guest_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isGuest) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person_outline, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text('Modo visitante', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Dados salvos apenas neste dispositivo',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final guestService = ref.read(guestServiceProvider);
                        await guestService.disableGuestMode();
                        ref.read(isGuestProvider.notifier).state = false;
                        if (context.mounted) context.go('/login');
                      },
                      child: const Text('Criar conta pra sincronizar'),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: user.userMetadata?['avatar_url'] != null
                        ? NetworkImage(user.userMetadata!['avatar_url'])
                        : null,
                    child: user.userMetadata?['avatar_url'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.userMetadata?['full_name'] ?? 'Sem nome',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(user.email ?? '', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tema'),
            subtitle: Text(_themeLabel(themeMode)),
            onTap: () => _showThemePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificações'),
            subtitle: const Text('Termômetro, contas futuras'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Contas recorrentes'),
            subtitle: const Text('Aluguel, internet, assinaturas'),
            onTap: () => context.push('/recurring'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('Diário financeiro'),
            subtitle: const Text('Reflexões sobre suas finanças'),
            onTap: () => context.push('/journal'),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Orçamento por categoria'),
            subtitle: const Text('Tetos mensais por tipo de gasto'),
            onTap: () => context.push('/budget'),
          ),
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Espaços compartilhados'),
              onTap: () {},
            ),
          const Divider(height: 40),

          if (isGuest)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair do modo visitante', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Seus dados locais serão mantidos'),
              onTap: () async {
                final guestService = ref.read(guestServiceProvider);
                await guestService.disableGuestMode();
                ref.read(isGuestProvider.notifier).state = false;
                if (context.mounted) context.go('/welcome');
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await ref.read(authControllerProvider).signOut();
              },
            ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
      case ThemeMode.system:
        return 'Segue o sistema';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.read(themeModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escolha o tema', style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            _themeOption(context, ref, ThemeMode.system, 'Segue o sistema', Icons.brightness_auto, current),
            _themeOption(context, ref, ThemeMode.light, 'Claro', Icons.light_mode, current),
            _themeOption(context, ref, ThemeMode.dark, 'Escuro', Icons.dark_mode, current),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext context, WidgetRef ref, ThemeMode mode, String label, IconData icon, ThemeMode current) {
    final active = current == mode;

    return ListTile(
      leading: Icon(icon, color: active ? AppColors.primary : null),
      title: Text(label),
      trailing: active ? const Icon(Icons.check, color: AppColors.primary) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: active,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
      onTap: () {
        ref.read(themeModeProvider.notifier).setTheme(mode);
        Navigator.pop(context);
      },
    );
  }
}