import 'package:flutter/foundation.dart';

@immutable
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.index,
    required this.total,
    required this.updatedAt,
    this.characterOffset,
    this.characterCount,
    this.contentHash,
  });

  final int bookId;
  final int index;
  final int total;
  final DateTime updatedAt;
  final int? characterOffset;
  final int? characterCount;
  final String? contentHash;

  double get fraction {
    if (characterOffset != null &&
        characterCount != null &&
        characterCount! > 0) {
      return (characterOffset! / characterCount!).clamp(0.0, 1.0).toDouble();
    }
    return total <= 1 ? 0.0 : (index / (total - 1)).clamp(0.0, 1.0).toDouble();
  }

  bool get isStarted => index > 0 || (characterOffset ?? 0) > 0;

  Map<String, dynamic> toJson() => {
    'id': bookId,
    'i': index,
    'n': total,
    't': updatedAt.millisecondsSinceEpoch,
    if (characterOffset != null) 'o': characterOffset,
    if (characterCount != null) 'l': characterCount,
    if (contentHash != null) 'h': contentHash,
  };

  static ReadingProgress? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final i = json['i'];
    final n = json['n'];
    final t = json['t'];
    if (id is! num || i is! num || n is! num) return null;
    final offset = json['o'];
    final count = json['l'];
    final hash = json['h'];
    final hasCharacterProgress =
        offset is num &&
        count is num &&
        count > 0 &&
        hash is String &&
        hash.isNotEmpty;
    return ReadingProgress(
      bookId: id.toInt(),
      index: i.toInt(),
      total: n.toInt(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(t is num ? t.toInt() : 0),
      characterOffset: hasCharacterProgress ? offset.toInt() : null,
      characterCount: hasCharacterProgress ? count.toInt() : null,
      contentHash: hasCharacterProgress ? hash : null,
    );
  }
}
