/// Build-time settings, passed with --dart-define-from-file=config/env.json. Without them the
/// app is fully usable on the phone and the account features are hidden.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get cloud =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      googleWebClientId.isNotEmpty;
}
