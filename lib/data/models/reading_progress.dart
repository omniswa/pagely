import 'package:flutter/foundation.dart';

@immutable
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.index,
    required this.total,
    required this.updatedAt,
  });

  final int bookId;
  final int index;
  final int total;
  final DateTime updatedAt;

  double get fraction =>
      total <= 1 ? 0.0 : (index / (total - 1)).clamp(0.0, 1.0).toDouble();
  bool get isStarted => index > 0;

  Map<String, dynamic> toJson() => {
        'id': bookId,
        'i': index,
        'n': total,
        't': updatedAt.millisecondsSinceEpoch,
      };

  static ReadingProgress? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final i = json['i'];
    final n = json['n'];
    final t = json['t'];
    if (id is! num || i is! num || n is! num) return null;
    return ReadingProgress(
      bookId: id.toInt(),
      index: i.toInt(),
      total: n.toInt(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(t is num ? t.toInt() : 0),
    );
  }
}
