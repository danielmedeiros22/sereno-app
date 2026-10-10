import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AvatarRemote {
  Future<Uint8List?> read(String owner);
  Future<void> save(String owner, Uint8List bytes);
  Future<void> reset(String owner);
}

class AvatarService {
  AvatarService({required this.owner, this.remote});
  final String? owner;
  final AvatarRemote? remote;
  String get _key =>
      'profile_avatar:v1:${owner == null ? 'guest' : 'user:$owner'}';

  Future<Uint8List?> readLocal() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return raw == null ? null : base64Decode(raw);
  }

  Future<void> _cache(Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = bytes == null
        ? await prefs.remove(_key)
        : await prefs.setString(_key, base64Encode(bytes));
    if (!saved) throw StateError('Não foi possível salvar a foto localmente.');
  }

  Future<Uint8List?> synchronize() async {
    if (owner == null || remote == null) return readLocal();
    final bytes = await remote!.read(owner!);
    await _cache(bytes);
    return bytes;
  }

  Future<void> save(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 524288) {
      throw ArgumentError('A foto deve ter no máximo 512 KB.');
    }
    if (owner != null) {
      if (remote == null) throw StateError('Sincronização indisponível.');
      await remote!.save(owner!, bytes);
    }
    await _cache(bytes);
  }

  Future<void> reset() async {
    if (owner != null) {
      if (remote == null) throw StateError('Sincronização indisponível.');
      await remote!.reset(owner!);
    }
    await _cache(null);
  }
}
