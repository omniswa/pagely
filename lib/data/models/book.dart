import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';

@immutable
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.added,
    required this.coverPath,
    required this.filePath,
    this.addedAt,
    this.contentVersion,
  });

  final int id;
  final String title;
  final String author;
  final String added;
  final DateTime? addedAt;
  final String coverPath;
  final String filePath;
  final String? contentVersion;

  /// Tolerant parser: returns null for entries that cannot be used.
  static Book? tryFromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final file = json['file'];
    if (id == null || file is! String || file.trim().isEmpty) return null;
    final added = (json['added'] is String)
        ? (json['added'] as String).trim()
        : '';
    return Book(
      id: id,
      title: _text(json['title'], 'Untitled'),
      author: _text(json['author'], 'Unknown author'),
      added: added,
      addedAt: _parseDate(added),
      coverPath: _text(json['cover'], ''),
      filePath: file.trim(),
      contentVersion: _contentVersion(json),
    );
  }

  Uri? get coverUri => coverPath.isEmpty ? null : AppConfig.resolve(coverPath);
  Uri get fileUri => AppConfig.resolve(filePath);

  String get addedLabel =>
      addedAt == null ? added : DateFormat.yMMMd().format(addedAt!);

  static int? _asInt(Object? v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  static String _text(Object? v, String fallback) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? fallback : s;
  }

  static String? _contentVersion(Map<String, dynamic> json) {
    const fields = [
      'content_version',
      'version',
      'etag',
      'ETag',
      'last_modified',
      'updated_at',
      'modified',
      'file_size',
      'size',
    ];
    final parts = <String>[];
    for (final field in fields) {
      final value = json[field];
      if (value is String && value.trim().isNotEmpty) {
        parts.add('$field:${value.trim()}');
      } else if (value is num) {
        parts.add('$field:$value');
      }
    }
    return parts.isEmpty ? null : parts.join('|');
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      return DateFormat('MMMM d, yyyy', 'en_US').parseLoose(s);
    } catch (_) {
      return DateTime.tryParse(s);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Book && other.id == id && other.contentVersion == contentVersion;

  @override
  int get hashCode => Object.hash(id, contentVersion);
}
