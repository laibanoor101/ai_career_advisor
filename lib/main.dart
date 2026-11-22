import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/app_theme.dart';
import 'screens/academic_profile_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/history_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseInitializationError;
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    firebaseInitializationError =
        'Sign-in is temporarily unavailable. Please try again later.';
  }
  runApp(
    CareerAdvisorApp(firebaseInitializationError: firebaseInitializationError),
  );
}

class CareerAdvisorApp extends StatefulWidget {
  const CareerAdvisorApp({
    super.key,
    this.firebaseInitializationError,
    this.authService,
  });

  final String? firebaseInitializationError;
  final AuthService? authService;

  @override
  State<CareerAdvisorApp> createState() => _CareerAdvisorAppState();
}

class _CareerAdvisorAppState extends State<CareerAdvisorApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AuthService? _authService;
  StreamSubscription<User?>? _authSubscription;
  String? _firebaseInitializationError;
  bool _authScreenOpened = false;
  bool _hasObservedSignedInUser = false;

  @override
  void initState() {
    super.initState();
    _firebaseInitializationError = widget.firebaseInitializationError;
    _authService = widget.authService;
    if (_authService == null && _firebaseInitializationError != null) return;

    try {
      _authService ??= AuthService();
      _hasObservedSignedInUser = _authService!.currentUser != null;
      _authSubscription = _authService!.authStateChanges.listen(
        _onAuthStateChanged,
        onError: (Object error) {
          debugPrint('Firebase auth-state stream failed: $error');
        },
      );
    } catch (error) {
      debugPrint('Firebase auth is unavailable: $error');
      _firebaseInitializationError =
          'Sign-in is temporarily unavailable. Please try again later.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onAuthStateChanged(User? user) {
    final signedOutAfterSession = user == null && _hasObservedSignedInUser;
    _hasObservedSignedInUser = user != null;

    if (user != null && _authScreenOpened) {
      _showSignedInDestination();
    } else if (signedOutAfterSession) {
      _showWelcomeDestination();
    }

    if (user != null && _authService != null) {
      unawaited(
        HistoryRepository(authService: _authService)
            .syncPending()
            .catchError((Object error) {
              debugPrint('Could not sync assessment history: $error');
            }),
      );
    }
  }

  void _openWelcomeDestination({bool? initialIsSignUp}) {
    final currentUser = _authService?.currentUser;
    if (currentUser != null) {
      _showSignedInDestination();
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _authScreenOpened = true;
    final route = MaterialPageRoute<void>(
      builder: (_) => AuthScreen(
        authService: _authService,
        firebaseInitializationError: _firebaseInitializationError,
        initialIsSignUp: initialIsSignUp,
      ),
    );
    unawaited(
      navigator.push<void>(route).whenComplete(() {
        _authScreenOpened = false;
      }),
    );
  }

  void _showSignedInDestination() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _hasObservedSignedInUser = true;
    _authScreenOpened = false;
    final route = MaterialPageRoute<void>(
      builder: (_) => AcademicProfileScreen(authService: _authService),
    );
    navigator.pushAndRemoveUntil<void>(route, (route) => false);
  }

  void _showWelcomeDestination() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _authScreenOpened = false;
    final route = MaterialPageRoute<void>(
      builder: (_) => SplashScreen(onContinue: _openWelcomeDestination),
    );
    navigator.pushAndRemoveUntil<void>(route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'AI Career Advisor',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: SplashScreen(onContinue: _openWelcomeDestination),
        );
      },
    );
  }
}
