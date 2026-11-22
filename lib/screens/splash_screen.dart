import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../widgets/theme_mode_button.dart';

/// Opening screen. Students tap Get Started to reach sign up or log in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onContinue});

  final void Function({bool? initialIsSignUp}) onContinue;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _logoScale;
  bool _continued = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _continue({bool? initialIsSignUp}) {
    if (_continued) return;
    _continued = true;
    widget.onContinue(initialIsSignUp: initialIsSignUp);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.onCanvas(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const _BackgroundGlow(
            alignment: Alignment(1.1, -0.85),
            color: AppTheme.primary,
            size: 320,
          ),
          const _BackgroundGlow(
            alignment: Alignment(-1.15, 0.55),
            color: AppTheme.cyan,
            size: 280,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryLight,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryLight,
                                blurRadius: 9,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI CAREER ADVISOR',
                        style: AppTheme.label(
                          fontSize: 11,
                          color: AppTheme.accent(context),
                        ).copyWith(letterSpacing: 1.1),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _continue(initialIsSignUp: true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.muted(context),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          'SKIP',
                          style: AppTheme.label(
                            fontSize: 11,
                            color: AppTheme.muted(context),
                          ).copyWith(letterSpacing: 1),
                        ),
                      ),
                      const ThemeModeButton(),
                    ],
                  ),
                  const Spacer(flex: 2),
                  ScaleTransition(scale: _logoScale, child: const _LogoMark()),
                  const SizedBox(height: 28),
                  Column(
                    children: [
                      Text(
                        'Your Future Career,',
                        textAlign: TextAlign.center,
                        style: AppTheme.heading(fontSize: 27, color: textColor),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFA855F7),
                            Color(0xFFEC4899),
                            AppTheme.cyan,
                          ],
                        ).createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          'Powered by AI',
                          textAlign: TextAlign.center,
                          style: AppTheme.heading(fontSize: 27),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Move past family pressure & confusion. Discover career pathways perfectly tuned to your skills, personality & grades.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      fontSize: 13,
                      color: AppTheme.muted(context),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Spacer(flex: 2),
                  _GradientButton(
                    label: 'Get Started',
                    onPressed: () => _continue(initialIsSignUp: true),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTheme.body(
                          fontSize: 12,
                          color: AppTheme.muted(context),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _continue(initialIsSignUp: false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accent(context),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Log In',
                          style: AppTheme.label(
                            fontSize: 12,
                            color: AppTheme.accent(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 224,
      height: 224,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: AppTheme.primary.withValues(alpha: isDark ? 0.52 : 0.28),
              ),
            ),
          ),
          Container(
            width: 190,
            height: 190,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: AppTheme.primaryLight.withValues(alpha: 0.72),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(
                    alpha: isDark ? 0.48 : 0.3,
                  ),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryLight.withValues(alpha: 0.24),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/app_logo.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: isDark ? 0.55 : 0.28),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text(label, style: AppTheme.title(fontSize: 16))],
            ),
          ),
        ),
      ),
    );
  }
}
