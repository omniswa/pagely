import 'dart:async';

import 'package:ending_flutter/core/errors.dart';
import 'package:ending_flutter/data/book_repository.dart';
import 'package:ending_flutter/data/local_store.dart';
import 'package:ending_flutter/data/models/book.dart';
import 'package:ending_flutter/data/models/parsed_book.dart';
import 'package:ending_flutter/data/providers.dart';
import 'package:ending_flutter/state/library_state.dart';
import 'package:ending_flutter/state/reading_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cached catalog does not show offline status until an offline refresh fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _CachedFailureBookRepository(
      preferences,
      const AppException('Offline', isOffline: true),
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        bookRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(catalogProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(catalogProvider.future);
    expect(container.read(catalogOfflineProvider), isFalse);

    await repository.refreshStarted.future;
    repository.failRefresh();
    expect(await container.read(catalogProvider.notifier).refresh(), isFalse);
    expect(container.read(catalogOfflineProvider), isTrue);
  });

  test(
    'a failed server refresh does not mark the catalog as offline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _CachedFailureBookRepository(
        preferences,
        const AppException('Server responded with 500.'),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          bookRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(catalogProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(catalogProvider.future);
      expect(container.read(catalogOfflineProvider), isFalse);

      await repository.refreshStarted.future;
      repository.failRefresh();
      expect(await container.read(catalogProvider.notifier).refresh(), isFalse);
      expect(container.read(catalogOfflineProvider), isFalse);
    },
  );

  test(
    'an offline launch without a cached catalog stays in error state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _OfflineBookRepository(preferences);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          bookRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(catalogProvider, (_, _) {});
      addTearDown(subscription.close);

      await expectLater(
        container.read(catalogProvider.future),
        throwsA(
          isA<AppException>().having(
            (error) => error.isOffline,
            'isOffline',
            true,
          ),
        ),
      );
      expect(container.read(catalogProvider), isA<AsyncError<CatalogResult>>());

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(repository.catalogRefreshes, 1);
    },
  );

  test(
    'a failed offline book download is not automatically repeated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _OfflineBookRepository(preferences);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          bookRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      const book = Book(
        id: 1,
        title: 'Book',
        author: 'Author',
        added: '',
        coverPath: '',
        filePath: '/book.txt',
      );
      final provider = parsedBookProvider(book);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await expectLater(
        container.read(provider.future),
        throwsA(isA<AppException>()),
      );
      expect(container.read(provider), isA<AsyncError<ParsedBook>>());

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(repository.downloadAttempts, 1);
    },
  );
}

class _OfflineBookRepository extends BookRepository {
  _OfflineBookRepository(SharedPreferences preferences)
    : super(client: http.Client(), store: LocalStore(preferences));

  int catalogRefreshes = 0;
  int downloadAttempts = 0;

  @override
  Future<CatalogResult?> loadCachedCatalog() async => null;

  @override
  Future<CatalogResult> refreshCatalog() async {
    catalogRefreshes++;
    throw const AppException('Offline', isOffline: true);
  }

  @override
  Future<bool> isDownloaded(Book book) async => false;

  @override
  Future<void> download(
    Book book, {
    void Function(double? progress)? onProgress,
  }) async {
    downloadAttempts++;
    throw const AppException('Offline', isOffline: true);
  }
}

class _CachedFailureBookRepository extends BookRepository {
  _CachedFailureBookRepository(SharedPreferences preferences, this.error)
    : super(client: http.Client(), store: LocalStore(preferences));

  final AppException error;
  final Completer<void> refreshStarted = Completer<void>();
  final Completer<CatalogResult> refreshResult = Completer<CatalogResult>();

  @override
  Future<CatalogResult?> loadCachedCatalog() async =>
      const CatalogResult(books: [], fromCache: true);

  @override
  Future<CatalogResult> refreshCatalog() {
    if (!refreshStarted.isCompleted) refreshStarted.complete();
    return refreshResult.future;
  }

  void failRefresh() => refreshResult.completeError(error);
}
