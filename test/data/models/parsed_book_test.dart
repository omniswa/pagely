import 'package:ending_flutter/data/models/parsed_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('character offsets survive changes to paragraph splitting', () {
    final oldParsing = parseBookText('One.\n\nTwo.');
    final newParsing = parseBookText('One.\nTwo.');

    expect(oldParsing.contentHash, newParsing.contentHash);
    expect(oldParsing.characterCount, newParsing.characterCount);
    expect(oldParsing.paragraphOffsets, [0, 5]);
    expect(oldParsing.paragraphIndexAtOffset(5), 1);
    expect(newParsing.paragraphIndexAtOffset(5), 0);
  });

  test('text changes produce a different content fingerprint', () {
    final original = parseBookText('First paragraph.\n\nSecond paragraph.');
    final changed = parseBookText('First paragraph.\n\nEdited paragraph.');

    expect(original.contentHash, isNot(changed.contentHash));
  });
}
