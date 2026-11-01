import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/book.dart';
import '../data/models/parsed_book.dart';
import '../data/models/reading_progress.dart';
import '../data/providers.dart';
import 'library_state.dart';

final progressProvider =
    NotifierProvider<ProgressNotifier, Map<int, ReadingProgress>>(
      ProgressNotifier.new,
    );

class ProgressNotifier extends Notifier<Map<int, ReadingProgress>> {
  @override
  Map<int, ReadingProgress> build() => ref.read(localStoreProvider).progress;

  void save(
    int bookId,
    int index,
    int total, {
    required int characterOffset,
    required int characterCount,
    required String contentHash,
  }) {
    state = {
      ...state,
      bookId: ReadingProgress(
        bookId: bookId,
        index: index,
        total: total,
        updatedAt: DateTime.now(),
        characterOffset: characterOffset,
        characterCount: characterCount,
        contentHash: contentHash,
      ),
    };
    unawaited(ref.read(localStoreProvider).saveProgress(state));
  }

  void clear(int bookId) {
    state = {...state}..remove(bookId);
    unawaited(ref.read(localStoreProvider).saveProgress(state));
  }
}

/// The most recently read book that has been started.
final lastReadBookProvider = Provider<Book?>((ref) {
  final books = ref.watch(catalogProvider).value?.books;
  final progress = ref.watch(progressProvider);
  if (books == null) return null;
  final started = progress.values.where((p) => p.isStarted).toList();
  if (started.isEmpty) return null;
  final latest = started.reduce(
    (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
  );
  return books.where((b) => b.id == latest.bookId).firstOrNull;
});

/// Ensures the book is on disk, then parses it off the UI thread.
final parsedBookProvider = FutureProvider.autoDispose.family<ParsedBook, Book>((
  ref,
  book,
) async {
  final repo = ref.read(bookRepositoryProvider);
  if (!await repo.isDownloaded(book)) {
    await ref.read(downloadsProvider.notifier).download(book);
  }
  final bytes = await repo.readBytes(book);
  return compute(parseBookBytes, bytes);
}, retry: (_, _) => null);
