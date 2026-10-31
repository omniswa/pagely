import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'book_repository.dart';
import 'local_store.dart';

/// Overridden in `main()` with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final localStoreProvider =
    Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPreferencesProvider)));

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(
    client: ref.watch(httpClientProvider),
    store: ref.watch(localStoreProvider),
  ),
);
