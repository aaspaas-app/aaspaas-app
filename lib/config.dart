class AppConfig {
  /// Where the Aas Paas plugin lives. Override at build time with --dart-define=API_BASE=https://aaspaas.app/wp-json/aaspaas/v1
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://zomo.pk/wp-json/aaspaas/v1',
  );

  /// The website itself (used for "manage my business" and the privacy page).
  static String get siteUrl =>
      apiBase.replaceFirst(RegExp(r'/wp-json/aaspaas/v1/?$'), '');

  static const String appName = 'Aas Paas';
  static const String version = '0.1.0';
}
