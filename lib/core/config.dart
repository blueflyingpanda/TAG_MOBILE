/// API configuration. Override for local development with
/// `flutter run --dart-define=API_BASE=http://10.0.2.2:8000`.
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://tag-api.servegame.com',
);

const googleNativeAuthUrl = '$apiBase/auth/google';

/// Google OAuth Web Client ID — must match the audience the backend verifies
/// against (`settings.oauth_gcloud_id`). Passed as `serverClientId` so the ID
/// token returned on-device is scoped to our server.
const googleWebClientId =
    '356207976842-m8hlg69cp2f9j2dhc1tdo0446g797po8.apps.googleusercontent.com';

const shareBaseUrl = 'https://blueflyingpanda.github.io/TAG/theme';
