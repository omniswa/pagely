import 'dart:convert';
import 'dart:typed_data';

class Paragraph {
  const Paragraph(this.text, {this.isHeading = false});
  final String text;
  final bool isHeading;
}

class Chapter {
  const Chapter(this.title, this.index);
  final String title;

  /// Index of the heading paragraph.
  final int index;
}

class ParsedBook {
  const ParsedBook({required this.paragraphs, required this.chapters});
  final List<Paragraph> paragraphs;
  final List<Chapter> chapters;

  /// The chapter that contains the paragraph at [index].
  Chapter? chapterAt(int index) {
    Chapter? found;
    for (final c in chapters) {
      if (c.index > index) break;
      found = c;
    }
    return found;
  }
}

final RegExp _headingPattern = RegExp(
  r'^(chapter|part|book|prologue|epilogue|preface|foreword|introduction|section|act|canto)\b.{0,70}$',
  caseSensitive: false,
);
final RegExp _blankLine = RegExp(r'\n[ \t]*\n');
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _nonLetters = RegExp(r'[^A-Za-z]');

/// Top-level so it can run in a background isolate via `compute`.
ParsedBook parseBookBytes(Uint8List bytes) =>
    parseBookText(utf8.decode(bytes, allowMalformed: true));

ParsedBook parseBookText(String raw) {
  final text = raw
      .replaceAll('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (text.isEmpty) return const ParsedBook(paragraphs: [], chapters: []);

  var chunks = text.split(_blankLine);
  // Some files separate paragraphs with a single newline only.
  if (chunks.length < 3 && text.length > 2000) chunks = text.split('\n');

  final paragraphs = <Paragraph>[];
  final chapters = <Chapter>[];
  for (final chunk in chunks) {
    final body = chunk.replaceAll(_whitespace, ' ').trim();
    if (body.isEmpty) continue;
    final heading = _isHeading(body);
    if (heading) chapters.add(Chapter(body, paragraphs.length));
    paragraphs.add(Paragraph(body, isHeading: heading));
  }
  return ParsedBook(paragraphs: paragraphs, chapters: chapters);
}

bool _isHeading(String s) {
  if (s.length > 80) return false;
  if (_headingPattern.hasMatch(s)) return true;
  final letters = s.replaceAll(_nonLetters, '');
  return letters.length >= 3 && s == s.toUpperCase() && !s.endsWith('.');
}
