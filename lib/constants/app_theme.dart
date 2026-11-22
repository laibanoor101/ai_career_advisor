import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Holds the active light or dark mode. Any screen can change
/// `themeNotifier.value` and the app rebuilds with the matching theme.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

/// Colors and text styles for AI Career Advisor.
///
/// Pass [AppTheme.lightTheme] and [AppTheme.darkTheme] to [MaterialApp].
class AppTheme {
  AppTheme._();

  // Canvas and surfaces.
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF1A2235);

  // Primary purple gradient stops.
  static const Color primary = Color(0xFF9333EA);
  static const Color primaryLight = Color(0xFFA855F7);

  // Accent colors.
  static const Color cyan = Color(0xFF06B6D4);
  static const Color emerald = Color(0xFF10B981);
  static const Color rose = Color(0xFFF43F5E);
  static const Color amber = Color(0xFFF59E0B);

  // Text. Slate gray is used for secondary copy on the dark canvas.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSlate = Color(0xFF94A3B8);

  // Light mode. Charcoal text on a pale canvas, with a deeper purple accent.
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFCBD5E1);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF475569);
  static const Color lightPrimary = Color(0xFF7E22CE);

  /// Main text color for the current brightness.
  static Color onCanvas(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : lightText;
  }

  /// Secondary text color for the current brightness.
  static Color muted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSlate
        : lightTextMuted;
  }

  /// Purple used for icons and selected borders in the current brightness.
  static Color accent(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryLight
        : lightPrimary;
  }

  /// Translucent glass fill (surface at 70% opacity).
  static Color get glassFill => surface.withValues(alpha: 0.7);

  /// Subtle white border used on glass cards.
  static Color get glassBorder => textPrimary.withValues(alpha: 0.12);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Large titles, such as a screen heading.
  static TextStyle heading({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.2,
    );
  }

  /// Section titles and card headings.
  static TextStyle title({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  /// Regular reading text.
  static TextStyle body({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textPrimary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.5,
    );
  }

  /// Small labels, such as chips and form captions.
  static TextStyle label({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textSlate,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
      letterSpacing: 0.2,
    );
  }

  static ThemeData get darkTheme {
    final baseText = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: textPrimary,
        secondary: cyan,
        onSecondary: background,
        surface: surface,
        onSurface: textPrimary,
        error: rose,
        onError: textPrimary,
      ),
      textTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: heading(fontSize: 20),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    );
  }

  static ThemeData get lightTheme {
    final baseText = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ).apply(bodyColor: lightText, displayColor: lightText);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: textPrimary,
        secondary: cyan,
        onSecondary: lightText,
        surface: lightSurface,
        onSurface: lightText,
        error: rose,
        onError: textPrimary,
      ),
      textTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: lightText,
        titleTextStyle: heading(fontSize: 20, color: lightText),
      ),
      iconTheme: const IconThemeData(color: lightText),
    );
  }
}
