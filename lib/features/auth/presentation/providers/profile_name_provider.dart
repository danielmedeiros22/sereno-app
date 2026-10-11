import 'dart:async';
import 'package:characters/characters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

String profileName(User? user) {
  for (final key in ['sereno_display_name', 'full_name', 'name']) {
    final value = user?.userMetadata?[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return user == null ? 'Visitante' : 'Sem nome';
}

final profileNameProvider =
    StateNotifierProvider.autoDispose<ProfileNameNotifier, String>((ref) {
  final owner = ref.watch(currentUserProvider.select((user) => user?.id));
  final notifier = ProfileNameNotifier(
      owner,
      profileName(ref.read(currentUserProvider)),
      ref.read(authControllerProvider));
  final timer = Timer.periodic(
      const Duration(seconds: 30), (_) => notifier.synchronize());
  ref.onDispose(timer.cancel);
  return notifier;
});

class ProfileNameNotifier extends StateNotifier<String> {
  ProfileNameNotifier(this.owner, String initial, this.auth) : super(initial) {
    unawaited(synchronize());
  }
  final String? owner;
  final AuthController auth;
  Future<void>? _sync;
  bool _saving = false;

  Future<void> synchronize() {
    if (owner == null || !mounted || _saving) return Future.value();
    return _sync ??= _read().whenComplete(() => _sync = null);
  }

  Future<void> _read() async {
    try {
      final user = await auth.readProfile();
      if (mounted && user?.id == owner) state = profileName(user);
    } catch (_) {/* Preserve the displayed name while offline. */}
  }

  Future<void> save(String value) async {
    final name = value.trim();
    if (name.isEmpty || name.characters.length > 80) {
      throw ArgumentError('Informe um nome entre 1 e 80 caracteres.');
    }
    if (owner == null || _saving || !mounted) {
      throw StateError('Conta indisponível.');
    }
    _saving = true;
    try {
      await _sync;
      if (!mounted) throw StateError('A conta mudou.');
      final user = await auth.updateDisplayName(owner!, name);
      if (!mounted || user?.id != owner) throw StateError('A conta mudou.');
      state = profileName(user);
    } finally {
      _saving = false;
    }
  }
}
