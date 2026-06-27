enum AppEnvironment { local, dev, prod }

class AppConfig {
  const AppConfig._();

  static final environment = AppEnvironment.values.byName(
    String.fromEnvironment('APP_ENV', defaultValue: 'local'),
  );

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://REPLACE_WITH_RENDER_BACKEND_URL',
  );
}
