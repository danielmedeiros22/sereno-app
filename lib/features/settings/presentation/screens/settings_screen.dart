import '../../../../features/recurring/presentation/screens/recurring_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

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
          // Perfil
          if (user != null) ...[
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
                        Text(
                          user.email ?? '',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tema'),
            subtitle: const Text('Segue o sistema'),
            onTap: () {},
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
            leading: const Icon(Icons.people_outline),
            title: const Text('Espaços compartilhados'),
            onTap: () {},
          ),
          const Divider(height: 40),
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
}
