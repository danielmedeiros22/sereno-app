import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract class MonthlyLimitRemote {
  Future<double?> fetch(String userId);
  Future<void> save(String userId, double value);
}

class MonthlyLimitRecord {
  const MonthlyLimitRecord(this.value, this.revision, {this.pending = false});

  final double value;
  final String revision;
  final bool pending;

  Map<String, dynamic> toJson() => {
        'value': value,
        'revision': revision,
        'pending': pending,
      };
}

/// Each account has its own local outbox. Guest values never enter an account.
class MonthlyLimitService {
  MonthlyLimitService({this.userId, this.remote});

  static const defaultLimit = 3500.0;
  final String? userId;
  final MonthlyLimitRemote? remote;
  Future<MonthlyLimitRecord>? _syncing;

  String get _key => userId == null
      ? 'monthly_spending_limit:v2:guest'
      : 'monthly_spending_limit:v2:user:$userId';

  static bool isValid(double value) =>
      value.isFinite && value >= 1 && value <= 50000;

  Future<MonthlyLimitRecord> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final value = (data['value'] as num).toDouble();
      if (!isValid(value)) throw const FormatException('Teto inválido');
      return MonthlyLimitRecord(value, data['revision'] as String,
          pending: data['pending'] == true);
    }
    // The old key has no owner. Keep it for guests, never attach it to a login.
    final legacy =
        userId == null ? prefs.getDouble('monthly_spending_limit') : null;
    return MonthlyLimitRecord(
      legacy != null && isValid(legacy) ? legacy : defaultLimit,
      'initial',
    );
  }

  Future<double> load() async => (await read()).value;

  Future<void> save(double value) async {
    if (!isValid(value)) {
      throw ArgumentError.value(
          value, 'value', 'Teto fora do intervalo permitido');
    }
    await _store(
        MonthlyLimitRecord(value, const Uuid().v4(), pending: userId != null));
  }

  Future<void> _store(MonthlyLimitRecord record,
      {String? expectedRevision}) async {
    final prefs = await SharedPreferences.getInstance();
    if (expectedRevision != null) {
      final raw = prefs.getString(_key);
      final revision = raw == null
          ? 'initial'
          : (jsonDecode(raw) as Map<String, dynamic>)['revision'];
      if (revision != expectedRevision) return;
    }
    if (!await prefs.setString(_key, jsonEncode(record.toJson()))) {
      throw StateError('Não foi possível salvar o teto mensal');
    }
  }

  Future<MonthlyLimitRecord> synchronize() {
    if (userId == null) return read();
    return _syncing ??= _synchronize().whenComplete(() => _syncing = null);
  }

  Future<MonthlyLimitRecord> _synchronize() async {
    final gateway = remote;
    if (gateway == null) throw StateError('Sincronização não configurada');
    final before = await read();
    if (before.pending) {
      // Conflict rule: the last write accepted by the server wins.
      await gateway.save(userId!, before.value);
      final latest = await read();
      if (latest.revision == before.revision) {
        await _store(MonthlyLimitRecord(before.value, before.revision),
            expectedRevision: before.revision);
      }
    } else {
      final value = await gateway.fetch(userId!);
      if (value != null) {
        if (!isValid(value)) {
          throw const FormatException('Teto remoto inválido');
        }
        final latest = await read();
        // A network response must not overwrite an edit made while it was away.
        if (latest.revision == before.revision && !latest.pending) {
          await _store(MonthlyLimitRecord(value, const Uuid().v4()),
              expectedRevision: before.revision);
        }
      }
    }
    return read();
  }
}
