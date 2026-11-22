import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// Sun in dark mode, moon in light mode. Tapping switches [themeNotifier].
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode != ThemeMode.light;
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppTheme.lightBorder;

        return IconButton(
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () {
            themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
          },
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppTheme.lightSurface,
            side: BorderSide(color: borderColor),
            foregroundColor: AppTheme.onCanvas(context),
          ),
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        );
      },
    );
  }
}