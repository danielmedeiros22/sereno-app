import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_provider.dart';

class TransactionSyncBanner extends ConsumerWidget {
  const TransactionSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(transactionOwnerProvider);
    if (owner == null) return const SizedBox.shrink();
    final status = ref.watch(transactionSyncStatusProvider);
    final legacy = ref.watch(legacyTransactionCountProvider).valueOrNull ?? 0;
    final message = switch (status) {
      TransactionSyncStatus.syncing => 'Sincronizando lançamentos…',
      TransactionSyncStatus.synced => 'Lançamentos sincronizados com sua conta',
      TransactionSyncStatus.failed =>
        'Lançamentos salvos neste dispositivo. Não foi possível sincronizar.',
      TransactionSyncStatus.disabled =>
        'Sincronização dos lançamentos ainda não ativada',
      TransactionSyncStatus.local => 'Lançamentos salvos neste dispositivo',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(message, style: Theme.of(context).textTheme.bodySmall),
      if (status == TransactionSyncStatus.failed)
        TextButton(
            onPressed: () =>
                ref.read(transactionListProvider.notifier).synchronize(),
            child: const Text('Tentar sincronizar novamente')),
      if (legacy > 0)
        TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                        title: const Text(
                            'Importar lançamentos deste dispositivo?'),
                        content: Text(
                            'Há $legacy lançamentos locais sem conta identificada. Importe apenas se forem seus. Eles serão vinculados à conta atual e sincronizados. A cópia local será preservada.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancelar')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Importar')),
                        ],
                      ));
              if (confirm != true || !context.mounted) return;
              // Abort if the user switched accounts while the dialog was open.
              if (ref.read(transactionOwnerProvider) != owner) return;
              try {
                await ref.read(transactionListProvider.notifier).importLegacy();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Lançamentos importados. A cópia local foi preservada.')));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Não foi possível importar agora. Seus registros locais foram preservados.')));
                }
              }
            },
            child: Text('Importar $legacy lançamentos locais')),
      const SizedBox(height: 12),
    ]);
  }
}
