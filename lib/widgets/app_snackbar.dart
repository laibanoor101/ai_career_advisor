import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

SnackBar buildAppSnackBar(
  BuildContext context,
  String message, {
  IconData icon = Icons.auto_awesome_rounded,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final foreground = isDark ? Colors.white : AppTheme.lightText;
  return SnackBar(
    content: Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accent(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: AppTheme.body(fontSize: 12, color: foreground),
          ),
        ),
      ],
    ),
    action: action,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    backgroundColor: isDark ? const Color(0xFF1E293B) : AppTheme.lightSurface,
    elevation: 8,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: isDark ? AppTheme.primaryLight : AppTheme.lightPrimary,
        width: 1,
      ),
    ),
  );
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  IconData icon = Icons.auto_awesome_rounded,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      buildAppSnackBar(
        context,
        message,
        icon: icon,
        action: action,
        duration: duration,
      ),
    );
}
