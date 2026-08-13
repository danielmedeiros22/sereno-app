import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import 'sync_provider.dart';
import 'sync_service.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingCountProvider);
    final theme = Theme.of(context);

    return syncStatus.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status == SyncStatus.idle || status == SyncStatus.synced) {
          return const SizedBox.shrink();
        }

        final pending = pendingCount.value ?? 0;

        return GestureDetector(
          onTap: () {
            if (status == SyncStatus.pending || status == SyncStatus.error) {
              ref.read(syncServiceProvider).syncPending();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _colorFor(status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == SyncStatus.syncing)
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _colorFor(status),
                    ),
                  )
                else
                  Icon(_iconFor(status), size: 14, color: _colorFor(status)),
                const SizedBox(width: 6),
                Text(
                  _labelFor(status, pending),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _colorFor(status),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _colorFor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return AppColors.primary;
      case SyncStatus.pending:
        return AppColors.alert;
      case SyncStatus.error:
        return AppColors.expense;
      default:
        return AppColors.income;
    }
  }

  IconData _iconFor(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return Icons.cloud_upload_outlined;
      case SyncStatus.error:
        return Icons.cloud_off_outlined;
      case SyncStatus.synced:
        return Icons.cloud_done_outlined;
      default:
        return Icons.cloud_outlined;
    }
  }

  String _labelFor(SyncStatus status, int pending) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Sincronizando...';
      case SyncStatus.pending:
        return '$pending pendente${pending == 1 ? "" : "s"}';
      case SyncStatus.error:
        return 'Erro ao sincronizar';
      case SyncStatus.synced:
        return 'Sincronizado';
      default:
        return '';
    }
  }
}