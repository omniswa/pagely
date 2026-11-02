import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../core/errors.dart';
import 'local_store.dart';
import 'models/book.dart';

class CatalogResult {
  const CatalogResult({required this.books, required this.fromCache});
  final List<Book> books;
  final bool fromCache;
}

/// Top-level so it can run in an isolate.
List<Book> parseCatalog(String raw) {
  final decoded = jsonDecode(raw);
  final List<dynamic> list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map && decoded['books'] is List) {
    list = decoded['books'] as List<dynamic>;
  } else {
    throw const FormatException('Unexpected catalog format');
  }
  final seen = <int>{};
  return [
    for (final item in list)
      if (item is Map<String, dynamic>)
        if (Book.tryFromJson(item) case final book? when seen.add(book.id))
          book,
  ];
}

class BookRepository {
  // Keep the named API while retaining library-private storage fields.
  BookRepository({required http.Client client, required LocalStore store})
    : _client = client, // ignore: prefer_initializing_formals
      _store = store; // ignore: prefer_initializing_formals

  final http.Client _client;
  final LocalStore _store;

  // ---- Catalog -------------------------------------------------------------

  /// Loads a previously cached catalog without waiting for the network.
  Future<CatalogResult?> loadCachedCatalog() async {
    try {
      final file = await _catalogFile();
      final fromFile = await file.exists();
      final raw = fromFile ? await file.readAsString() : _store.catalogCache;
      if (raw == null) return null;

      final List<Book> books;
      try {
        books = await compute(parseCatalog, raw);
      } on FormatException {
        if (fromFile) {
          await file.delete();
        } else {
          await _store.removeCatalogCache();
        }
        return null;
      }

      if (!fromFile) {
        await _saveCatalogCache(raw);
        await _store.removeCatalogCache();
      }
      return CatalogResult(books: books, fromCache: true);
    } catch (error) {
      throw _toAppException(error);
    }
  }

  /// Fetches the latest catalog and saves it to app support storage.
  Future<CatalogResult> refreshCatalog() async {
    try {
      final response = await _client
          .get(
            AppConfig.resolve(AppConfig.catalogPath),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) {
        throw AppException('Server responded with ${response.statusCode}.');
      }
      final raw = utf8.decode(response.bodyBytes);
      final books = await compute(parseCatalog, raw);
      await _saveCatalogCache(raw);
      return CatalogResult(books: books, fromCache: false);
    } catch (error) {
      throw _toAppException(error);
    }
  }

  // ---- Book files ----------------------------------------------------------

  Future<File> _catalogFile() async {
    final base = await getApplicationSupportDirectory();
    return File('${base.path}${Platform.pathSeparator}catalog.json');
  }

  Future<void> _saveCatalogCache(String raw) async {
    final file = await _catalogFile();
    final temp = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    await temp.writeAsString(raw, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<Directory> _booksDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}books');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(Book book) async => File(
    '${(await _booksDir()).path}${Platform.pathSeparator}${book.id}.txt',
  );

  Future<bool> isDownloaded(Book book) async {
    final file = await _fileFor(book);
    if (!await file.exists()) return false;
    final version = book.contentVersion;
    return version == null || _store.downloadedVersions[book.id] == version;
  }

  Future<Uint8List> readBytes(Book book) async {
    try {
      if (!await isDownloaded(book)) {
        throw const AppException(
          'This book needs to be refreshed before it can be read offline.',
        );
      }
      return await (await _fileFor(book)).readAsBytes();
    } on AppException {
      rethrow;
    } on FileSystemException {
      throw const AppException('This book is not available offline yet.');
    }
  }

  /// Streams the book to disk (via a temp file) reporting progress in 0..1.
  Future<void> download(
    Book book, {
    void Function(double? progress)? onProgress,
  }) async {
    final target = await _fileFor(book);
    final temp = File('${target.path}.part');
    IOSink? sink;
    try {
      final response = await _client
          .send(http.Request('GET', book.fileUri))
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw AppException(
          "Couldn't download this book (HTTP ${response.statusCode}).",
        );
      }
      final total = response.contentLength;
      var received = 0;
      sink = temp.openWrite();
      final deadline = DateTime.now().add(AppConfig.downloadTimeout);
      final stream = StreamIterator<List<int>>(response.stream);
      try {
        while (true) {
          final remaining = deadline.difference(DateTime.now());
          if (remaining <= Duration.zero) {
            throw TimeoutException('Book download timed out.');
          }
          final wait = remaining < AppConfig.streamTimeout
              ? remaining
              : AppConfig.streamTimeout;
          if (!await stream.moveNext().timeout(wait)) break;

          final chunk = stream.current;
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) onProgress?.call(received / total);
        }
      } finally {
        await stream.cancel();
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
      await _store.saveDownloadedVersion(book.id, book.contentVersion);
    } catch (error) {
      try {
        await sink?.close();
      } catch (_) {}
      if (await temp.exists()) await temp.delete();
      throw _toAppException(error);
    }
  }

  Future<void> deleteBook(Book book) async {
    try {
      final file = await _fileFor(book);
      if (await file.exists()) await file.delete();
      await _store.saveDownloadedVersion(book.id, null);
    } catch (error) {
      throw _toAppException(error);
    }
  }

  Future<void> deleteAll() async {
    try {
      final dir = await _booksDir();
      if (await dir.exists()) await dir.delete(recursive: true);
      await _store.clearDownloadedVersions();
    } catch (error) {
      throw _toAppException(error);
    }
  }

  AppException _toAppException(Object error) {
    if (error is AppException) return error;
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return const AppException(
        "You're offline or the server can't be reached.",
        isOffline: true,
      );
    }
    if (error is FileSystemException) {
      return const AppException("Couldn't save data on this device.");
    }
    if (error is FormatException) {
      return const AppException('The library data is invalid.');
    }
    return const AppException('Something went wrong. Please try again.');
  }
}
