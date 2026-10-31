import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
        if (Book.tryFromJson(item) case final book? when seen.add(book.id)) book,
  ];
}

class BookRepository {
  BookRepository({required http.Client client, required LocalStore store})
      : _client = client,
        _store = store;

  final http.Client _client;
  final LocalStore _store;

  // ---- Catalog -------------------------------------------------------------

  /// Network first, falling back to the last cached catalog when offline.
  Future<CatalogResult> loadCatalog() async {
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
      await _store.saveCatalogCache(raw);
      return CatalogResult(books: books, fromCache: false);
    } catch (error) {
      final cached = _store.catalogCache;
      if (cached != null) {
        try {
          return CatalogResult(books: await compute(parseCatalog, cached), fromCache: true);
        } catch (_) {
          // Fall through to the original error.
        }
      }
      throw _toAppException(error);
    }
  }

  // ---- Book files ----------------------------------------------------------

  Future<Directory> _booksDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}books');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(Book book) async =>
      File('${(await _booksDir()).path}${Platform.pathSeparator}${book.id}.txt');

  Future<bool> isDownloaded(Book book) async => (await _fileFor(book)).exists();

  Future<Uint8List> readBytes(Book book) async {
    try {
      return await (await _fileFor(book)).readAsBytes();
    } on FileSystemException {
      throw const AppException('This book is not available offline yet.');
    }
  }

  /// Streams the book to disk (via a temp file) reporting progress in 0..1.
  Future<void> download(Book book, {void Function(double? progress)? onProgress}) async {
    final target = await _fileFor(book);
    final temp = File('${target.path}.part');
    IOSink? sink;
    try {
      final response = await _client
          .send(http.Request('GET', book.fileUri))
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw AppException("Couldn't download this book (HTTP ${response.statusCode}).");
      }
      final total = response.contentLength;
      var received = 0;
      sink = temp.openWrite();
      await for (final chunk in response.stream.timeout(AppConfig.streamTimeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
    } catch (error) {
      try {
        await sink?.close();
      } catch (_) {}
      if (await temp.exists()) await temp.delete();
      throw _toAppException(error);
    }
  }

  Future<void> deleteBook(Book book) async {
    final file = await _fileFor(book);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    final dir = await _booksDir();
    if (await dir.exists()) await dir.delete(recursive: true);
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
      return const AppException("Couldn't save the book on this device.");
    }
    if (error is FormatException) {
      return const AppException('The library data is invalid.');
    }
    return const AppException('Something went wrong. Please try again.');
  }
}
