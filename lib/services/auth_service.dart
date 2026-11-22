import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    return credential;
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      await (_googleInitialization ??= _googleSignIn.initialize());
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthServiceException(
          'Google sign-in did not return an ID token. Please try again.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (error) {
      throw AuthServiceException(friendlyErrorMessage(error));
    }
  }

  Future<void> sendPasswordReset(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try {
      await (_googleInitialization ??= _googleSignIn.initialize());
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('Google session sign-out failed: $error');
    }
  }

  static String friendlyAuthMessageForCode(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' => 'No account was found for that email.',
    'wrong-password' => 'The password is incorrect.',
    'invalid-credential' => 'The email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for that email.',
    'weak-password' => 'Choose a password with at least 6 characters.',
    'network-request-failed' =>
      'Connection problem. Check your internet and try again.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    _ => 'Authentication failed. Please check your details and try again.',
  };

  static String friendlyErrorMessage(Object error) {
    if (error is AuthServiceException) return error.message;
    if (error is FirebaseAuthException) {
      return friendlyAuthMessageForCode(error.code);
    }
    if (error is GoogleSignInException ||
        error is PlatformException ||
        error is MissingPluginException) {
      return friendlyGoogleSignInError(error);
    }
    return 'Something went wrong. Please try again.';
  }

  static String friendlyGoogleSignInError(Object error) {
    if (error is AuthServiceException) return error.message;
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return 'Google sign-in was cancelled.';
    }
    final details = error.toString().toLowerCase();
    if (details.contains('developer_error') ||
        details.contains('apiexception: 10') ||
        details.contains('status code: 10')) {
      return 'Google sign-in is not configured for this app yet. Add the '
          'Android debug SHA-1 in Firebase, download a fresh '
          'google-services.json, and try again.';
    }
    return 'Google sign-in could not be completed. Please try again.';
  }
}
