import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  service.startListening();
  ref.onDispose(() => service.dispose());
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.statusStream;
});

final pendingCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncStatusProvider);
  final service = ref.read(syncServiceProvider);
  return service.getPendingCount();
});