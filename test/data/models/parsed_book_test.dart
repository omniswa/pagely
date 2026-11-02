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

  test('detects headings wrapped in three dashes, not dash-only lines', () {
    final parsed = parseBookText(
      '--- Chapter Title ---\n\n------\n\n--- ------ ---',
    );

    expect(parsed.chapters, hasLength(1));
    expect(parsed.chapters.single.title, '--- Chapter Title ---');
    expect(parsed.paragraphs.map((paragraph) => paragraph.isHeading), [
      true,
      false,
      false,
    ]);
  });

  test('does not detect dialogue or short shouts as headings', () {
    final parsed = parseBookText(
      'Part of me wanted to leave.\n\n'
      'Act now, she said.\n\n'
      'NO!\n\n'
      'WAIT',
    );

    expect(parsed.chapters, isEmpty);
    expect(parsed.paragraphs.map((paragraph) => paragraph.isHeading), [
      false,
      false,
      false,
      false,
    ]);
  });

  test('detects structured and multiword uppercase headings', () {
    final parsed = parseBookText(
      'Chapter 1: The Beginning\n\n'
      'Part II\n\n'
      'THE BEGINNING\n\n'
      'Prologue: The Beginning',
    );

    expect(parsed.chapters.map((chapter) => chapter.title), [
      'Chapter 1: The Beginning',
      'Part II',
      'THE BEGINNING',
      'Prologue: The Beginning',
    ]);
  });
}
