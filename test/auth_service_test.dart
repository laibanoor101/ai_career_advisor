import 'package:ai_career_advisor/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService friendly auth messages', () {
    test('maps common Firebase authentication error codes', () {
      expect(
        AuthService.friendlyAuthMessageForCode('invalid-email'),
        'Enter a valid email address.',
      );
      expect(
        AuthService.friendlyAuthMessageForCode('user-not-found'),
        'No account was found for that email.',
      );
      expect(
        AuthService.friendlyAuthMessageForCode('wrong-password'),
        'The password is incorrect.',
      );
      expect(
        AuthService.friendlyAuthMessageForCode('invalid-credential'),
        'The email or password is incorrect.',
      );
      expect(
        AuthService.friendlyAuthMessageForCode('email-already-in-use'),
        'An account already exists for that email.',
      );
      expect(
        AuthService.friendlyAuthMessageForCode('weak-password'),
        'Choose a password with at least 6 characters.',
      );
      expect(
        AuthService.friendlyAuthMessageForCode('network-request-failed'),
        'Connection problem. Check your internet and try again.',
      );
      expect(
        AuthService.friendlyAuthMessageForCode('too-many-requests'),
        'Too many attempts. Please wait and try again.',
      );
    });

    test('reports Google API setup errors helpfully', () {
      expect(
        AuthService.friendlyGoogleSignInError(Exception('ApiException: 10')),
        contains('debug SHA-1'),
      );
      expect(
        AuthService.friendlyAuthMessageForCode('some-new-code'),
        isNot(contains('some-new-code')),
      );
    });
  });
}
