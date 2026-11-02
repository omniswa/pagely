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
  static const _downloadedVersionsKey = 'downloaded_versions_v1';
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

  Map<int, String> get downloadedVersions {
    final raw = _prefs.getString(_downloadedVersionsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (int.tryParse(entry.key) case final int id)
            if (entry.value is String) id: entry.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDownloadedVersion(int bookId, String? version) async {
    final versions = downloadedVersions;
    if (version == null) {
      versions.remove(bookId);
    } else {
      versions[bookId] = version;
    }
    final saved = await _prefs.setString(
      _downloadedVersionsKey,
      jsonEncode({
        for (final entry in versions.entries) '${entry.key}': entry.value,
      }),
    );
    if (!saved) throw StateError('Could not save downloaded book version.');
  }

  Future<void> clearDownloadedVersions() async {
    await _prefs.remove(_downloadedVersionsKey);
  }

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
