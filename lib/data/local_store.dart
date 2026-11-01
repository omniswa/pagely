import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_settings.dart';
import 'models/reading_progress.dart';

/// Thin, typed wrapper around SharedPreferences.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _catalogKey = 'catalog_cache_v1';
  static const _favoritesKey = 'favorites_v1';
  static const _downloadedKey = 'downloaded_v1';
  static const _progressKey = 'progress_v1';
  static const _settingsKey = 'settings_v1';

  String? get catalogCache => _prefs.getString(_catalogKey);
  Future<void> removeCatalogCache() async {
    await _prefs.remove(_catalogKey);
  }

  Set<int> get favorites => _readIntSet(_favoritesKey);
  Future<void> saveFavorites(Set<int> ids) => _writeIntSet(_favoritesKey, ids);

  Set<int> get downloaded => _readIntSet(_downloadedKey);
  Future<void> saveDownloaded(Set<int> ids) =>
      _writeIntSet(_downloadedKey, ids);

  Map<int, ReadingProgress> get progress {
    final raw = _prefs.getString(_progressKey);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final progress = list
          .map(ReadingProgress.tryFromJson)
          .whereType<ReadingProgress>();
      return {for (final entry in progress) entry.bookId: entry};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveProgress(Map<int, ReadingProgress> value) =>
      _prefs.setString(
        _progressKey,
        jsonEncode(value.values.map((p) => p.toJson()).toList()),
      );

  AppSettings get settings {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) =>
      _prefs.setString(_settingsKey, jsonEncode(s.toJson()));

  Set<int> _readIntSet(String key) =>
      (_prefs.getStringList(key) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> _writeIntSet(String key, Set<int> ids) =>
      _prefs.setStringList(key, ids.map((e) => '$e').toList());
}
