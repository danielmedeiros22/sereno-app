import 'dart:convert';
import 'package:characters/characters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'default_categories.dart';

abstract class CategoryRemote {
  Future<List<CategoryItem>> fetch(String owner);
  Future<void> save(String owner, CategoryItem category);
}

/// Append-only definitions: records retain their original name and emoji.
class CategoryService {
  CategoryService({this.owner, this.remote});
  final String? owner;
  final CategoryRemote? remote;
  Future<void> _serial = Future.value();
  Future<void>? _sync;
  String get storageKey =>
      'categories:v1:${owner == null ? 'guest' : 'user:$owner'}';

  Future<T> _locked<T>(Future<T> Function() action) {
    final next = _serial.then((_) => action());
    _serial = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
  }

  Future<void> _write(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, jsonEncode(rows))) {
      throw StateError(
          'Não foi possível salvar a categoria neste dispositivo.');
    }
  }

  Future<List<CategoryItem>> getAll() => _locked(() async =>
      (await _read()).map((row) => CategoryItem.fromJson(row)).toList());
  Future<int> pendingCount() => _locked(() async =>
      (await _read()).where((row) => row['pending'] == true).length);

  static CategoryItem validate(String name, String icon, String type) {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final cleanIcon = icon.trim();
    if (cleanName.isEmpty ||
        cleanName.characters.length > 40 ||
        cleanName.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      throw ArgumentError('Use um nome de 1 a 40 caracteres.');
    }
    // Grapheme-aware: flags, skin tones and ZWJ families remain intact.
    final hasEmoji = cleanIcon.runes.any((r) =>
        (r >= 0x1F000 && r <= 0x1FAFF) ||
        (r >= 0x2300 && r <= 0x27FF) ||
        r == 0x00A9 ||
        r == 0x00AE ||
        r == 0x203C ||
        r == 0x2049 ||
        r == 0x2122 ||
        r == 0x2139 ||
        r == 0x2B50 ||
        r == 0x2B55 ||
        r == 0x3030 ||
        r == 0x303D ||
        r == 0x3297 ||
        r == 0x3299 ||
        r == 0x20E3 ||
        (r >= 0x2B05 && r <= 0x2B07) ||
        r == 0x2934 ||
        r == 0x2935 ||
        r == 0x2B1B ||
        r == 0x2B1C);
    if (cleanIcon.characters.length != 1 ||
        !hasEmoji ||
        cleanIcon.length > 64) {
      throw ArgumentError(
          'Escolha um único emoji pelo teclado ou pelas sugestões.');
    }
    if (type != 'expense' && type != 'income') {
      throw ArgumentError('Tipo de categoria inválido.');
    }
    return CategoryItem(name: cleanName, icon: cleanIcon, type: type);
  }

  Future<CategoryItem> add(String name, String icon, String type) =>
      _locked(() async {
        final category = validate(name, icon, type);
        final rows = await _read();
        final existing = [
          ...defaultCategories,
          ...rows.map(CategoryItem.fromJson)
        ];
        if (existing.any((item) => item.key == category.key)) {
          throw ArgumentError(
              'Já existe uma categoria com esse nome neste tipo.');
        }
        rows.add({...category.toJson(), 'pending': owner != null});
        await _write(rows);
        return category;
      });

  Future<void> synchronize() {
    if (owner == null || remote == null) return Future.value();
    return _sync ??= _synchronize().whenComplete(() => _sync = null);
  }

  Future<void> _synchronize() async {
    final snapshot = await _locked(_read);
    for (final row in snapshot.where((row) => row['pending'] == true)) {
      final category = CategoryItem.fromJson(row);
      await remote!.save(owner!, category);
      await _locked(() async {
        final rows = await _read();
        for (final current in rows) {
          if (CategoryItem.fromJson(current).key == category.key) {
            current['pending'] = false;
          }
        }
        await _write(rows);
      });
    }
    final cloud = await remote!.fetch(owner!);
    await _locked(() async {
      final local = await _read();
      final merged = {
        for (final item in cloud) item.key: {...item.toJson(), 'pending': false}
      };
      for (final row in local.where((row) => row['pending'] == true)) {
        merged[CategoryItem.fromJson(row).key] = row;
      }
      await _write(merged.values.toList());
    });
  }
}
