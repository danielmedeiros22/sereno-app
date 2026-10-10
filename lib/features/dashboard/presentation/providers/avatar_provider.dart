import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/avatar_service.dart';
import '../../data/supabase_avatar_remote.dart';

final avatarServiceProvider = Provider<AvatarService>((ref) {
  final owner = ref.watch(transactionOwnerProvider);
  return AvatarService(
      owner: owner,
      remote:
          owner == null ? null : SupabaseAvatarRemote(SupabaseService.client));
});

final avatarPickerProvider =
    Provider<Future<Uint8List?> Function()>((ref) => () async {
          final file = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 256,
              maxHeight: 256,
              imageQuality: 80);
          if (file == null) return null;
          if (await file.length() > 5 * 1024 * 1024) {
            throw ArgumentError('Imagem muito grande.');
          }
          final source = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(source,
              targetWidth: 256, allowUpscaling: false);
          try {
            final frame = await codec.getNextFrame();
            try {
              final data =
                  await frame.image.toByteData(format: ui.ImageByteFormat.png);
              if (data == null) {
                throw StateError('Não foi possível preparar a imagem.');
              }
              return data.buffer
                  .asUint8List(data.offsetInBytes, data.lengthInBytes);
            } finally {
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
        });

final avatarProvider =
    StateNotifierProvider.autoDispose<AvatarNotifier, AsyncValue<Uint8List?>>(
        (ref) {
  final notifier = AvatarNotifier(ref.watch(avatarServiceProvider));
  final timer = Timer.periodic(
      const Duration(seconds: 30), (_) => notifier.synchronize());
  ref.onDispose(timer.cancel);
  return notifier;
});

class AvatarNotifier extends StateNotifier<AsyncValue<Uint8List?>> {
  AvatarNotifier(this.service) : super(const AsyncValue.loading()) {
    ready = _load();
  }
  final AvatarService service;
  late final Future<void> ready;
  Future<void>? _sync;
  bool _saving = false;

  Future<void> _load() async {
    try {
      final bytes = await service.readLocal();
      if (mounted) state = AsyncValue.data(bytes);
      await synchronize();
    } catch (error, stack) {
      if (mounted) state = AsyncValue.error(error, stack);
    }
  }

  Future<void> synchronize() {
    if (!mounted || _saving) return Future<void>.value();
    return _sync ??= _synchronize().whenComplete(() => _sync = null);
  }

  Future<void> _synchronize() async {
    try {
      final bytes = await service.synchronize();
      if (mounted) state = AsyncValue.data(bytes);
    } catch (_) {/* Retain the cached photo on connection failure. */}
  }

  Future<void> change(Uint8List? bytes) async {
    if (_saving) return;
    _saving = true;
    try {
      await ready;
      await _sync;
      if (!mounted) return;
      if (bytes == null) {
        await service.reset();
      } else {
        await service.save(bytes);
      }
      if (mounted) state = AsyncValue.data(bytes);
    } finally {
      _saving = false;
    }
  }
}
