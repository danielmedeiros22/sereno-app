import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_queue.dart';

class SyncService {
  final SyncQueue _queue = SyncQueue();
  final _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SupabaseClient get _client => Supabase.instance.client;

  bool get _isLoggedIn => _client.auth.currentUser != null;

  void startListening() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && _isLoggedIn) {
        syncPending();
      }
    });
  }

  void stopListening() {
    _connectivitySub?.cancel();
  }

  Future<void> addToQueue(SyncOperation op) async {
    await _queue.add(op);
    _statusController.add(SyncStatus.pending);

    if (_isLoggedIn) {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        await syncPending();
      }
    }
  }

  Future<void> syncPending() async {
    if (_isSyncing || !_isLoggedIn) return;
    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      final ops = await _queue.getAll();
      if (ops.isEmpty) {
        _statusController.add(SyncStatus.synced);
        _isSyncing = false;
        return;
      }

      for (final op in ops) {
        try {
          await _executeOperation(op);
          await _queue.remove(op.id);
        } catch (e) {
          debugPrint('Sync error for ${op.id}: $e');
        }
      }

      final remaining = await _queue.pendingCount;
      _statusController.add(remaining == 0 ? SyncStatus.synced : SyncStatus.error);
    } catch (e) {
      debugPrint('Sync batch error: $e');
      _statusController.add(SyncStatus.error);
    }

    _isSyncing = false;
  }

  Future<void> _executeOperation(SyncOperation op) async {
    final userId = _client.auth.currentUser!.id;

    switch (op.action) {
      case 'insert':
        final data = Map<String, dynamic>.from(op.data);
        data['user_id'] = userId;
        await _client.from(op.table).upsert(data);
        break;
      case 'update':
        await _client.from(op.table).update(op.data).eq('id', op.data['id']);
        break;
      case 'delete':
        await _client.from(op.table).delete().eq('id', op.data['id']);
        break;
    }
  }

  Future<void> pullFromCloud() async {
    if (!_isLoggedIn) return;
    _statusController.add(SyncStatus.syncing);

    try {
      final userId = _client.auth.currentUser!.id;

      // Pull spaces
      final spaces = await _client.from('spaces').select().eq('user_id', userId);
      debugPrint('Pulled ${spaces.length} spaces');

      // Pull transactions (if space exists)
      if (spaces.isNotEmpty) {
        final spaceIds = spaces.map((s) => s['id']).toList();
        final transactions = await _client
            .from('transactions')
            .select()
            .inFilter('space_id', spaceIds)
            .order('date', ascending: false);
        debugPrint('Pulled ${transactions.length} transactions');
      }

      _statusController.add(SyncStatus.synced);
    } catch (e) {
      debugPrint('Pull error: $e');
      _statusController.add(SyncStatus.error);
    }
  }

  Future<int> getPendingCount() async {
    return _queue.pendingCount;
  }

  void dispose() {
    stopListening();
    _statusController.close();
  }
}

enum SyncStatus { idle, pending, syncing, synced, error }