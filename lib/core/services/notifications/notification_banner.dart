import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import 'notification_provider.dart';
import 'notification_service.dart';

class NotificationBanner extends ConsumerWidget {
  const NotificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);
    final theme = Theme.of(context);

    return notifications.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          children: items.map((n) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _colorFor(n.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _colorFor(n.type).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(_iconFor(n.type), size: 20, color: _colorFor(n.type)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: _colorFor(n.type), fontSize: 13)),
                      Text(n.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref.read(notificationServiceProvider).dismiss(n.id);
                  },
                  icon: Icon(Icons.close, size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'overdue':
        return AppColors.expense;
      case 'warning':
        return AppColors.alert;
      default:
        return AppColors.primary;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'overdue':
        return Icons.warning_amber;
      case 'warning':
        return Icons.schedule;
      default:
        return Icons.info_outline;
    }
  }
}