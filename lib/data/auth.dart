import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';

import '../core/config.dart';
import 'models.dart';

/// Decodes our aux JWT (client-side, for UI only) into a [User].
/// Returns null for malformed or expired tokens.
User? userFromToken(String? token) {
  if (token == null) return null;
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
        as Map<String, dynamic>;

    final exp = (payload['exp'] as num?)?.toInt();
    if (exp != null && DateTime.now().millisecondsSinceEpoch >= exp * 1000) return null;

    final email = payload['email'] as String?;
    final username = payload['username'] as String?;
    return User(
      id: payload['user_id'].toString(),
      email: email,
      username: (username != null && username.isNotEmpty)
          ? username
          : (email != null && email.contains('@') ? email.split('@').first : 'Player'),
      picture: payload['picture'] as String?,
      admin: payload['admin'] as bool? ?? false,
    );
  } catch (_) {
    return null;
  }
}

class SignInCancelled implements Exception {}

/// Native Google Sign-In (Credential Manager on Android). Returns a Google ID
/// token whose audience is our web client, ready for POST /auth/google.
class GoogleAuth {
  static Future<void>? _init;

  static Future<void> _ensureInitialized() =>
      _init ??= GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);

  static Future<String> signIn() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email', 'profile']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('Google sign-in returned no ID token');
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw SignInCancelled();
      rethrow;
    }
  }

  /// Clears the cached Google account so the next sign-in shows the picker.
  static Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
