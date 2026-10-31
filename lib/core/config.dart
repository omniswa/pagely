/// App-wide configuration. Override the host with
/// `--dart-define=BASE_URL=https://example.com`.
abstract final class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://omniswa.github.io/ending-repo',
  );
  static const String catalogPath = 'books.json';
  static const String version = '1.0.0';
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration streamTimeout = Duration(seconds: 30);

  static Uri resolve(String path) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    return base.resolve(path);
  }
}
