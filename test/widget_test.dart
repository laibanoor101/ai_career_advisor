import 'package:ai_career_advisor/main.dart';
import 'package:ai_career_advisor/screens/academic_profile_screen.dart';
import 'package:ai_career_advisor/screens/auth_screen.dart';
import 'package:ai_career_advisor/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Welcome remains visible until the user acts', (tester) async {
    _setWelcomeViewport(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(CareerAdvisorApp(authService: _FakeAuthService()));

    expect(find.text('Your Future Career,'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Your Future Career,'), findsOneWidget);
    expect(find.text('Create Student Account'), findsNothing);
  });

  testWidgets('Get Started opens Sign Up when signed out', (tester) async {
    _setWelcomeViewport(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(CareerAdvisorApp(authService: _FakeAuthService()));

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Create Student Account'), findsOneWidget);
  });

  testWidgets('Log In link opens the Log In tab when signed out', (
    tester,
  ) async {
    _setWelcomeViewport(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(CareerAdvisorApp(authService: _FakeAuthService()));

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('Skip opens Sign Up when signed out', (tester) async {
    _setWelcomeViewport(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(CareerAdvisorApp(authService: _FakeAuthService()));

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    expect(find.text('Create Student Account'), findsOneWidget);
  });

  testWidgets('AuthScreen back arrow returns to Welcome', (tester) async {
    _setWelcomeViewport(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(CareerAdvisorApp(authService: _FakeAuthService()));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Your Future Career,'), findsOneWidget);
  });

  testWidgets('a signed-in Welcome action opens Academic Profile', (
    tester,
  ) async {
    _setWelcomeViewport(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      CareerAdvisorApp(authService: _FakeAuthService(currentUser: _FakeUser())),
    );

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.byType(AcademicProfileScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AcademicProfileScreen), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);
  });

  testWidgets('a new device defaults to Sign Up and can switch tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Create Student Account'), findsOneWidget);
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('a returning account defaults to Log In and restores email', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasAccount': true,
      'lastEmail': 'student@example.com',
    });

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    final emailField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(emailField.controller?.text, 'student@example.com');
  });
}

void _setWelcomeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.currentUser});

  @override
  final User? currentUser;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    throw UnimplementedError();
  }
}

class _FakeUser implements User {
  @override
  String get uid => 'test-user';

  @override
  String? get displayName => null;

  @override
  String? get email => 'student@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
