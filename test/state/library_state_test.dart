import 'dart:async';

import 'package:ending_flutter/core/errors.dart';
import 'package:ending_flutter/data/book_repository.dart';
import 'package:ending_flutter/data/local_store.dart';
import 'package:ending_flutter/data/models/book.dart';
import 'package:ending_flutter/data/providers.dart';
import 'package:ending_flutter/state/library_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const book = Book(
    id: 1,
    title: 'Book',
    author: 'Author',
    added: '',
    coverPath: '',
    filePath: '/book.txt',
  );

  test('clearAll refuses to delete files while a download is active', () async {
    final (container, repository) = await _createContainer();
    addTearDown(container.dispose);
    final notifier = container.read(downloadsProvider.notifier);

    final download = notifier.download(book);
    await repository.downloadStarted.future;

    await expectLater(notifier.clearAll(), throwsA(isA<AppException>()));
    expect(repository.deleteAllCalls, 0);

    repository.finishDownload();
    await download;
  });

  test('downloads wait for clearAll to finish', () async {
    final (container, repository) = await _createContainer();
    addTearDown(container.dispose);
    final notifier = container.read(downloadsProvider.notifier);

    final clear = notifier.clearAll();
    await repository.deleteAllStarted.future;

    final download = notifier.download(book);
    expect(repository.downloadStarted.isCompleted, isFalse);

    repository.finishDeleteAll();
    await clear;
    await repository.downloadStarted.future;

    repository.finishDownload();
    await download;
  });
}

Future<(ProviderContainer, _DownloadsBookRepository)> _createContainer() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final repository = _DownloadsBookRepository(preferences);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      bookRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return (container, repository);
}

class _DownloadsBookRepository extends BookRepository {
  _DownloadsBookRepository(SharedPreferences preferences)
    : super(client: http.Client(), store: LocalStore(preferences));

  final downloadStarted = Completer<void>();
  final _downloadCompleter = Completer<void>();
  final deleteAllStarted = Completer<void>();
  final _deleteAllCompleter = Completer<void>();
  var deleteAllCalls = 0;

  @override
  Future<void> download(
    Book book, {
    void Function(double? progress)? onProgress,
  }) async {
    downloadStarted.complete();
    await _downloadCompleter.future;
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCalls++;
    deleteAllStarted.complete();
    await _deleteAllCompleter.future;
  }

  void finishDownload() => _downloadCompleter.complete();

  void finishDeleteAll() => _deleteAllCompleter.complete();
}
