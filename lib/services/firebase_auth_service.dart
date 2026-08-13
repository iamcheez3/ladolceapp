import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();

  /// Whether the "Continue with Google" option should be offered.
  /// Hidden on Apple platforms to comply with App Store guideline 4.8:
  /// offering a third-party login requires an equivalent privacy-focused
  /// option (e.g. Sign in with Apple). Re-enable for iOS/macOS once
  /// Sign in with Apple is implemented.
  static bool get isGoogleAuthAvailable =>
      defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS;

  String get _serverClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim() ?? '';

  bool _googleInitialized = false;

  Future<UserCredential> signInWithGoogle() async {
    await _ensureFirebaseInitialized();
    await _ensureGoogleInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception('Google Sign-In is not supported on this platform.');
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not return an ID token.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _ensureFirebaseInitialized();
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
    await FirebaseAuth.instance.signOut();
  }

  /// Best-effort: permanently delete the current Firebase user record.
  /// May fail with `requires-recent-login` if the last sign-in is too old —
  /// callers should treat failure as non-fatal and continue their flow.
  Future<void> deleteCurrentUser() async {
    await _ensureFirebaseInitialized();
    await FirebaseAuth.instance.currentUser?.delete();
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _googleInitialized = true;
  }
}
