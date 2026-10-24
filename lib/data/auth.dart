import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudUser {
  const CloudUser(this.id, this.email, {this.name, this.photoUrl});
  final String id;
  final String? email;

  /// What Google calls the person, and the link to their Google photo.
  final String? name, photoUrl;
}

/// Signs in with Google and exchanges the Google ID token for a Supabase session.
/// Signing in is optional; nothing in the app needs it.
abstract interface class AuthService {
  CloudUser? get current;
  Stream<CloudUser?> get changes;

  /// Throws [AuthFailure] with a message fit for the user.
  Future<CloudUser> signIn();
  Future<void> signOut();

  /// Deletes the account and all its cloud data, then signs out.
  Future<void> deleteAccount();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client, {required this.webClientId});
  final SupabaseClient _client;
  final String webClientId;
  bool _ready = false;

  CloudUser? _user(User? u) {
    if (u == null) return null;
    final m = u.userMetadata;
    String? text(String a, String b) {
      final v = (m?[a] ?? m?[b]);
      return v is String && v.isNotEmpty ? v : null;
    }

    return CloudUser(
      u.id,
      u.email,
      name: text('full_name', 'name'),
      photoUrl: text('avatar_url', 'picture'),
    );
  }

  @override
  CloudUser? get current => _user(_client.auth.currentUser);

  @override
  Stream<CloudUser?> get changes =>
      _client.auth.onAuthStateChange.map((e) => _user(e.session?.user));

  @override
  Future<CloudUser> signIn() async {
    try {
      if (!_ready) {
        await GoogleSignIn.instance.initialize(serverClientId: webClientId);
        _ready = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(
          'Google did not return a sign-in token. Try again.',
        );
      }
      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final user = _user(res.user);
      if (user == null) {
        throw const AuthFailure('Sign-in did not complete. Try again.');
      }
      return user;
    } on GoogleSignInException catch (e) {
      throw AuthFailure(switch (e.code) {
        GoogleSignInExceptionCode.canceled => 'Sign-in cancelled.',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not set up correctly for this build.',
        _ => 'Google sign-in failed. Check your connection and try again.',
      });
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Already signed out of Google.
    }
  }

  @override
  Future<void> deleteAccount() async {
    await _client.rpc<void>('delete_my_account');
    await signOut();
    try {
      await GoogleSignIn.instance.disconnect();
    } on Object {
      // Nothing left to disconnect.
    }
  }
}
