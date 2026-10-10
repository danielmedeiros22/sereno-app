import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'avatar_service.dart';

class SupabaseAvatarRemote implements AvatarRemote {
  SupabaseAvatarRemote(this.client);
  final SupabaseClient client;
  static const bucket = 'profile-avatars';

  void _check(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('A conta mudou durante a operação.');
    }
  }

  @override
  Future<Uint8List?> read(String owner) async {
    _check(owner);
    final files = await client.storage.from(bucket).list(
        path: owner, searchOptions: const SearchOptions(search: 'avatar.png'));
    _check(owner);
    if (!files.any((file) => file.name == 'avatar.png')) return null;
    final bytes =
        await client.storage.from(bucket).download('$owner/avatar.png');
    _check(owner);
    return bytes;
  }

  @override
  Future<void> save(String owner, Uint8List bytes) async {
    _check(owner);
    await client.storage.from(bucket).uploadBinary('$owner/avatar.png', bytes,
        fileOptions: const FileOptions(
            upsert: true, contentType: 'image/png', cacheControl: '0'));
    _check(owner);
  }

  @override
  Future<void> reset(String owner) async {
    _check(owner);
    await client.storage.from(bucket).remove(['$owner/avatar.png']);
    _check(owner);
  }
}
