import 'package:ending_flutter/data/models/reading_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses character progress when available', () {
    final progress = ReadingProgress(
      bookId: 1,
      index: 1,
      total: 10,
      characterOffset: 75,
      characterCount: 100,
      contentHash: 'fingerprint',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    );

    expect(progress.fraction, 0.75);
    expect(progress.isStarted, isTrue);
    expect(ReadingProgress.tryFromJson(progress.toJson())?.characterOffset, 75);
  });

  test('continues reading legacy paragraph-based progress', () {
    final progress = ReadingProgress.tryFromJson({
      'id': 1,
      'i': 4,
      'n': 10,
      't': 1,
    });

    expect(progress, isNotNull);
    expect(progress!.fraction, closeTo(4 / 9, 0.0001));
    expect(progress.contentHash, isNull);
  });
}
