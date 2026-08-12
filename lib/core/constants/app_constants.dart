class AppConstants {
  const AppConstants._();

  static const appName = 'Sereno';
  static const appTagline = 'Suas finanças com calma';

  // Deep link para OAuth callback
  static const authRedirectUrl = 'io.sereno.app://login-callback';

  // Storage keys
  static const themePreferenceKey = 'theme_preference';

  // Sync
  static const syncBatchSize = 50;
  static const syncRetryLimit = 5;
}
