import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuthService instance = FirebaseAuthService._();

  static const String _serverClientId =
      '883890977471-bto2o0qi9gh2aglrpj4a499mvgo9btvp.apps.googleusercontent.com';

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
