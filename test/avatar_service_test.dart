import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sereno_app/features/dashboard/data/avatar_service.dart';

class AvatarMemoryRemote implements AvatarRemote {
  final photos = <String, Uint8List>{};
  bool offline = false;
  @override
  Future<Uint8List?> read(String owner) async {
    if (offline) throw StateError('offline');
    return photos[owner];
  }

  @override
  Future<void> save(String owner, Uint8List bytes) async {
    if (offline) throw StateError('offline');
    photos[owner] = bytes;
  }

  @override
  Future<void> reset(String owner) async {
    photos.remove(owner);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('photo reaches a clean device and reset propagates', () async {
    final remote = AvatarMemoryRemote();
    final first = AvatarService(owner: 'a', remote: remote);
    await first.save(Uint8List.fromList([1, 2, 3]));
    SharedPreferences.setMockInitialValues({});
    final second = AvatarService(owner: 'a', remote: remote);
    expect(await second.synchronize(), [1, 2, 3]);
    await second.reset();
    expect(await first.synchronize(), isNull);
    expect(await first.readLocal(), isNull);
  });
  test('guest and accounts have isolated photos', () async {
    final remote = AvatarMemoryRemote();
    final a = AvatarService(owner: 'a', remote: remote);
    final b = AvatarService(owner: 'b', remote: remote);
    final guest = AvatarService(owner: null);
    await a.save(Uint8List.fromList([1]));
    await guest.save(Uint8List.fromList([2]));
    expect(await b.synchronize(), isNull);
    expect(await guest.readLocal(), [2]);
    expect(await a.readLocal(), [1]);
    expect(remote.photos.keys, ['a']);
  });
  test('failed upload preserves the previous cached and remote photo',
      () async {
    final remote = AvatarMemoryRemote();
    final service = AvatarService(owner: 'a', remote: remote);
    await service.save(Uint8List.fromList([1]));
    remote.offline = true;
    await expectLater(service.save(Uint8List.fromList([2])), throwsStateError);
    expect(await service.readLocal(), [1]);
    expect(remote.photos['a'], [1]);
  });
  test('empty and oversized images are rejected before upload', () async {
    final remote = AvatarMemoryRemote();
    final service = AvatarService(owner: 'a', remote: remote);
    await expectLater(service.save(Uint8List(0)), throwsArgumentError);
    await expectLater(service.save(Uint8List(524289)), throwsArgumentError);
    expect(remote.photos, isEmpty);
  });
}
