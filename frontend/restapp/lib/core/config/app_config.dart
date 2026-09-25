class AppConfig {
  static const String baseUrl = 'http://localhost:5000';

  static const String apiPrefix = '';

  static String get apiBaseUrl => '$baseUrl$apiPrefix';
}
