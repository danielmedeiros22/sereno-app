import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/services/guest_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/profile_name_provider.dart';
import '../../../auth/presentation/widgets/edit_profile_name_button.dart';
import 'clear_records_screen.dart';
import '../../../dashboard/presentation/providers/avatar_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);
    final themeMode = ref.watch(themeModeProvider);
    final customPhoto = ref.watch(avatarProvider).valueOrNull;

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
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _editablePhoto(
                      CircleAvatar(
                        radius: 28,
                        foregroundImage: customPhoto == null
                            ? null
                            : MemoryImage(customPhoto),
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.person_outline,
                            color: Colors.white, size: 28),
                      ),
                      size: 56),
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
                  _editablePhoto(CircleAvatar(
                    radius: 24,
                    foregroundImage: customPhoto != null
                        ? MemoryImage(customPhoto)
                        : user.userMetadata?['avatar_url'] != null
                            ? NetworkImage(user.userMetadata!['avatar_url'])
                            : null,
                    child: const Icon(Icons.person),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.watch(profileNameProvider),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(user.email ?? '',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const EditProfileNameButton(),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sair da conta'),
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
            onTap: () => context.push('/notifications'),
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
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Relatórios'),
            subtitle: const Text('Gastos por período e categoria'),
            onTap: () => context.push('/reports'),
          ),
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Espaços compartilhados'),
              onTap: () {},
            ),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            title: const Text('Limpar registros',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Escolher dados e período para excluir'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const ClearRecordsScreen())),
          ),
          if (isGuest)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair do modo visitante',
                  style: TextStyle(color: Colors.red)),
              subtitle: const Text('Seus dados locais serão mantidos'),
              onTap: () async {
                final guestService = ref.read(guestServiceProvider);
                await guestService.disableGuestMode();
                ref.read(isGuestProvider.notifier).state = false;
                if (context.mounted) context.go('/welcome');
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

  bool _changing = false;

  Widget _editablePhoto(Widget photo, {double size = 48}) => Tooltip(
        message: 'Trocar imagem',
        child: Semantics(
          button: true,
          label: 'Trocar imagem',
          child: InkWell(
            onTap: _changing ? null : _changePhoto,
            borderRadius: BorderRadius.circular(size / 2),
            child: SizedBox(
                width: size,
                height: size,
                child: Stack(children: [
                  Positioned.fill(child: photo),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: _changing
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.photo_camera,
                                size: 12, color: Colors.white),
                      )),
                ])),
          ),
        ),
      );

  Future<void> _changePhoto() async {
    final owner = ref.read(transactionOwnerProvider);
    final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escolher imagem'),
                  subtitle: Text(owner == null
                      ? 'Salva apenas neste dispositivo'
                      : 'Foto privada, sincronizada com sua conta'),
                  onTap: () => Navigator.pop(context, 'pick')),
              ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(owner == null
                      ? 'Usar ícone padrão'
                      : 'Usar foto da conta Google'),
                  onTap: () => Navigator.pop(context, 'reset')),
              ListTile(
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(context)),
            ])));
    if (!mounted ||
        choice == null ||
        owner != ref.read(transactionOwnerProvider)) {
      return;
    }
    setState(() => _changing = true);
    try {
      final bytes =
          choice == 'pick' ? await ref.read(avatarPickerProvider)() : null;
      if (!mounted ||
          (choice == 'pick' && bytes == null) ||
          owner != ref.read(transactionOwnerProvider)) {
        return;
      }
      await ref.read(avatarProvider.notifier).change(bytes);
      if (mounted && owner == ref.read(transactionOwnerProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(owner == null
                ? 'Imagem salva neste dispositivo.'
                : 'Foto atualizada na sua conta.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível trocar a imagem. Verifique a conexão e tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider).signOut();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível sair da conta. Tente novamente.')));
      }
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
            _themeOption(context, ref, ThemeMode.system, 'Segue o sistema',
                Icons.brightness_auto, current),
            _themeOption(context, ref, ThemeMode.light, 'Claro',
                Icons.light_mode, current),
            _themeOption(context, ref, ThemeMode.dark, 'Escuro',
                Icons.dark_mode, current),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext context, WidgetRef ref, ThemeMode mode,
      String label, IconData icon, ThemeMode current) {
    final active = current == mode;

    return ListTile(
      leading: Icon(icon, color: active ? AppColors.primary : null),
      title: Text(label),
      trailing:
          active ? const Icon(Icons.check, color: AppColors.primary) : null,
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
