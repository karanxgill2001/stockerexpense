class AppConfig {
  const AppConfig._();

  static const String defaultStockGoogleScriptUrl = String.fromEnvironment(
    'GOOGLE_SCRIPT_URL',
    defaultValue: '',
  );

  static const String
  defaultCredentialsGoogleScriptUrl = String.fromEnvironment(
    'CREDENTIALS_SCRIPT_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbzm5FI1ESg3BzZo51sNZMYVKI3s4VUbyEZ_y1lOuJSveUM4a96oeCkUR7rgIXyWcftB/exec',
  );

  static bool get isGoogleSheetsConfigured =>
      defaultStockGoogleScriptUrl.trim().isNotEmpty;

  static bool get isCredentialsBackendConfigured =>
      defaultCredentialsGoogleScriptUrl.trim().isNotEmpty;
}
