import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class GuestBanner extends StatefulWidget {
  const GuestBanner({super.key});

  @override
  State<GuestBanner> createState() => _GuestBannerState();
}

class _GuestBannerState extends State<GuestBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.1)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.cloud_off_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Modo visitante', style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 2),
              Text('Crie uma conta pra sincronizar seus dados entre dispositivos.', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ]),
          ),
          IconButton(onPressed: () => setState(() => _dismissed = true), icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
        ],
      ),
    );
  }
}