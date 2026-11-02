import 'dart:io';

import 'package:ending_flutter/core/errors.dart';
import 'package:ending_flutter/data/book_repository.dart';
import 'package:ending_flutter/data/local_store.dart';
import 'package:ending_flutter/data/models/book.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'book-repository-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => supportDirectory.path,
        );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('redownloads a cached book when its catalog version changes', () async {
    final preferences = await SharedPreferences.getInstance();
    var requests = 0;
    final repository = BookRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response(
          requests == 1 ? 'old contents' : 'new contents',
          200,
        );
      }),
      store: LocalStore(preferences),
    );
    final version1 = _book(version: '1');
    final version2 = _book(version: '2');

    expect(version1, isNot(version2));
    await repository.download(version1);
    expect(await repository.isDownloaded(version1), isTrue);
    expect(await repository.isDownloaded(version2), isFalse);
    await expectLater(
      repository.readBytes(version2),
      throwsA(isA<AppException>()),
    );

    await repository.download(version2);

    expect(await repository.isDownloaded(version2), isTrue);
    expect(
      String.fromCharCodes(await repository.readBytes(version2)),
      'new contents',
    );
    expect(requests, 2);
  });

  test('reads supported freshness fields from catalog entries', () {
    final book = Book.tryFromJson({
      'id': 42,
      'file': 'books/42.txt',
      'version': 3,
      'size': 120,
    });

    expect(book?.contentVersion, 'version:3|size:120');
  });
}

Book _book({required String version}) => Book(
  id: 42,
  title: 'Book',
  author: 'Author',
  added: '',
  coverPath: '',
  filePath: 'books/42.txt',
  contentVersion: 'version:$version',
);
