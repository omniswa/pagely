import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_repository.dart';
import '../data/models/book.dart';
import '../data/providers.dart';

// ---- Catalog -----------------------------------------------------------------

final catalogProvider = AsyncNotifierProvider<CatalogNotifier, CatalogResult>(
  CatalogNotifier.new,
  retry: (_, _) => null,
);

class CatalogNotifier extends AsyncNotifier<CatalogResult> {
  Future<bool>? _refreshing;

  @override
  Future<CatalogResult> build() async {
    final repository = ref.read(bookRepositoryProvider);
    final cached = await repository.loadCachedCatalog();
    if (cached == null) return repository.refreshCatalog();

    Timer.run(() => unawaited(refresh()));
    return cached;
  }

  /// Returns true when fresh data was fetched, false when offline/failed.
  Future<bool> refresh() =>
      _refreshing ??= _refreshCatalog().whenComplete(() => _refreshing = null);

  Future<bool> _refreshCatalog() async {
    try {
      final result = await ref.read(bookRepositoryProvider).refreshCatalog();
      state = AsyncData(result);
      return true;
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
      return false;
    }
  }
}

// ---- Query (search / filter / sort) ----------------------------------------------

enum LibraryFilter {
  all('All'),
  favorites('Favorites'),
  downloaded('Downloads');

  const LibraryFilter(this.label);
  final String label;
}

enum LibrarySort {
  newest('Newest first'),
  oldest('Oldest first'),
  title('Title A–Z'),
  author('Author A–Z');

  const LibrarySort(this.label);
  final String label;
}

@immutable
class LibraryQuery {
  const LibraryQuery({
    this.text = '',
    this.filter = LibraryFilter.all,
    this.sort = LibrarySort.newest,
  });

  final String text;
  final LibraryFilter filter;
  final LibrarySort sort;

  LibraryQuery copyWith({
    String? text,
    LibraryFilter? filter,
    LibrarySort? sort,
  }) => LibraryQuery(
    text: text ?? this.text,
    filter: filter ?? this.filter,
    sort: sort ?? this.sort,
  );
}

final libraryQueryProvider =
    NotifierProvider<LibraryQueryNotifier, LibraryQuery>(
      LibraryQueryNotifier.new,
    );

class LibraryQueryNotifier extends Notifier<LibraryQuery> {
  @override
  LibraryQuery build() => const LibraryQuery();

  void setText(String v) => state = state.copyWith(text: v);
  void setFilter(LibraryFilter v) => state = state.copyWith(filter: v);
  void setSort(LibrarySort v) => state = state.copyWith(sort: v);
}

// ---- Favorites -----------------------------------------------------------------

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<int>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.read(localStoreProvider).favorites;

  void toggle(int id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
    unawaited(ref.read(localStoreProvider).saveFavorites(next));
  }
}

// ---- Downloads -------------------------------------------------------------------

@immutable
class DownloadsState {
  const DownloadsState({this.completed = const {}, this.active = const {}});

  final Set<int> completed;

  /// bookId -> progress (null means indeterminate).
  final Map<int, double?> active;

  DownloadsState copyWith({Set<int>? completed, Map<int, double?>? active}) =>
      DownloadsState(
        completed: completed ?? this.completed,
        active: active ?? this.active,
      );
}

final downloadsProvider = NotifierProvider<DownloadsNotifier, DownloadsState>(
  DownloadsNotifier.new,
);

class DownloadsNotifier extends Notifier<DownloadsState> {
  final Map<int, Future<void>> _inflight = {};

  @override
  DownloadsState build() =>
      DownloadsState(completed: ref.read(localStoreProvider).downloaded);

  /// De-duplicates concurrent downloads of the same book.
  Future<void> download(Book book) =>
      _inflight[book.id] ??= _run(book).whenComplete(() {
        _inflight.remove(book.id);
      });

  Future<void> _run(Book book) async {
    _setProgress(book.id, null);
    try {
      await ref
          .read(bookRepositoryProvider)
          .download(book, onProgress: (p) => _setProgress(book.id, p));
      final done = {...state.completed, book.id};
      state = state.copyWith(completed: done);
      unawaited(ref.read(localStoreProvider).saveDownloaded(done));
    } finally {
      state = state.copyWith(active: {...state.active}..remove(book.id));
    }
  }

  void _setProgress(int id, double? value) {
    final has = state.active.containsKey(id);
    final prev = state.active[id];
    if (has && prev != null && value != null && (value - prev).abs() < 0.01) {
      return;
    }
    state = state.copyWith(active: {...state.active, id: value});
  }

  Future<void> remove(Book book) async {
    await ref.read(bookRepositoryProvider).deleteBook(book);
    final done = {...state.completed}..remove(book.id);
    state = state.copyWith(completed: done);
    unawaited(ref.read(localStoreProvider).saveDownloaded(done));
  }

  Future<void> clearAll() async {
    await ref.read(bookRepositoryProvider).deleteAll();
    state = const DownloadsState();
    unawaited(ref.read(localStoreProvider).saveDownloaded(const {}));
  }
}

// ---- Derived: filtered + sorted list ------------------------------------------------

final visibleBooksProvider = Provider<AsyncValue<List<Book>>>((ref) {
  final catalog = ref.watch(catalogProvider);
  final query = ref.watch(libraryQueryProvider);
  final favorites = ref.watch(favoritesProvider);
  final downloaded = ref.watch(downloadsProvider.select((s) => s.completed));

  return catalog.whenData((result) {
    final needle = query.text.trim().toLowerCase();
    final list = result.books.where((b) {
      if (needle.isNotEmpty &&
          !b.title.toLowerCase().contains(needle) &&
          !b.author.toLowerCase().contains(needle)) {
        return false;
      }
      switch (query.filter) {
        case LibraryFilter.all:
          return true;
        case LibraryFilter.favorites:
          return favorites.contains(b.id);
        case LibraryFilter.downloaded:
          return downloaded.contains(b.id);
      }
    }).toList();
    list.sort(_comparator(query.sort));
    return list;
  });
});

Comparator<Book> _comparator(LibrarySort sort) {
  int byTitle(Book a, Book b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  switch (sort) {
    case LibrarySort.title:
      return byTitle;
    case LibrarySort.author:
      return (a, b) {
        final c = a.author.toLowerCase().compareTo(b.author.toLowerCase());
        return c != 0 ? c : byTitle(a, b);
      };
    case LibrarySort.newest:
      return (a, b) {
        final c = (b.addedAt ?? epoch).compareTo(a.addedAt ?? epoch);
        return c != 0 ? c : b.id.compareTo(a.id);
      };
    case LibrarySort.oldest:
      return (a, b) {
        final c = (a.addedAt ?? epoch).compareTo(b.addedAt ?? epoch);
        return c != 0 ? c : a.id.compareTo(b.id);
      };
  }
}
