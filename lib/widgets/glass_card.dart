import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// A panel that looks like frosted glass in dark mode and a crisp
/// white card in light mode.
///
/// Pass [onTap] to make the card tappable. Set [isSelected] to show a
/// purple glow border, for example on a chosen quiz option.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.isSelected = false,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool isSelected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final borderColor = isSelected
        ? AppTheme.accent(context)
        : (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppTheme.lightBorder);

    Widget content = Padding(padding: padding ?? EdgeInsets.zero, child: child);

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    if (!isDark) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.lightSurface,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.lightText.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            if (isSelected)
              BoxShadow(
                color: AppTheme.lightPrimary.withValues(alpha: 0.22),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
        ),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235).withValues(alpha: 0.7),
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
