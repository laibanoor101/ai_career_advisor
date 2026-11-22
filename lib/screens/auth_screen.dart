import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/theme_mode_button.dart';

/// Sign up and log in. Either action continues to the academic profile.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialIsSignUp,
    this.authService,
    this.firebaseInitializationError,
  });

  final bool? initialIsSignUp;
  final AuthService? authService;
  final String? firebaseInitializationError;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignUp = widget.initialIsSignUp ?? true;
  bool _hidePassword = true;
  bool _acceptedTerms = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  late String? _errorMessage = widget.firebaseInitializationError;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreAccountPreferences();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    if (_isSignUp && !_acceptedTerms) {
      setState(() {
        _errorMessage = 'Please accept the terms to create an account.';
      });
      return;
    }

    final service = widget.authService;
    if (service == null) {
      setState(() {
        _errorMessage =
            widget.firebaseInitializationError ??
            'Sign-in is unavailable right now. Please try again later.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isGoogleLoading = false;
      _errorMessage = null;
    });
    try {
      if (_isSignUp) {
        await service.signUpWithEmail(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await service.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }
      await _rememberSuccessfulAccount(_emailController.text);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = AuthService.friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    final service = widget.authService;
    if (service == null) {
      setState(() {
        _errorMessage =
            widget.firebaseInitializationError ??
            'Sign-in is unavailable right now. Please try again later.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      await service.signInWithGoogle();
      await _rememberSuccessfulAccount(service.currentUser?.email);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = AuthService.friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreAccountPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final hasAccount = preferences.getBool('hasAccount') ?? false;
      final lastEmail = preferences.getString('lastEmail');
      if (!mounted) return;
      setState(() {
        if (widget.initialIsSignUp == null) {
          _isSignUp = !hasAccount;
        }
        if (_emailController.text.isEmpty && lastEmail != null) {
          _emailController.text = lastEmail;
        }
      });
    } catch (error) {
      debugPrint('Could not restore saved account preferences: $error');
    }
  }

  Future<void> _rememberSuccessfulAccount(String? email) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('hasAccount', true);
    final normalizedEmail = email?.trim();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      await preferences.setString('lastEmail', normalizedEmail);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (_validateEmail(email) != null) {
      setState(() => _errorMessage = 'Enter a valid email address first.');
      return;
    }
    final service = widget.authService;
    if (service == null) {
      setState(() {
        _errorMessage =
            widget.firebaseInitializationError ??
            'Password reset is unavailable right now. Please try again later.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await service.sendPasswordReset(email);
      if (mounted) {
        showAppSnackBar(
          context,
          'Password reset email sent.',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = AuthService.friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.onCanvas(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const _SoftGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _BackButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        const ThemeModeButton(),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _AuthToggle(
                      isSignUp: _isSignUp,
                      onChanged: (isSignUp) {
                        if (_isLoading) return;
                        setState(() {
                          _isSignUp = isSignUp;
                          _errorMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isSignUp ? 'Create Student Account' : 'Welcome Back',
                      style: AppTheme.heading(fontSize: 24, color: textColor),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _isSignUp
                          ? 'Start your AI-powered career evaluation.'
                          : 'Log in to view past career assessments.',
                      style: AppTheme.body(
                        fontSize: 13,
                        color: AppTheme.muted(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isSignUp) ...[
                      _LabeledField(
                        label: 'Full Name',
                        hint: 'Muhammad Ali / Fatima Noor',
                        icon: Icons.person_outline_rounded,
                        controller: _nameController,
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Enter your name.'
                            : null,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _LabeledField(
                      label: 'Student Email Address',
                      hint: 'student@smiu.edu.pk',
                      icon: Icons.mail_outline_rounded,
                      controller: _emailController,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'Password',
                      hint: 'At least 6 characters',
                      icon: Icons.lock_outline_rounded,
                      controller: _passwordController,
                      validator: _validatePassword,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      trailing: _isSignUp
                          ? null
                          : TextButton(
                              onPressed: _isLoading ? null : _sendPasswordReset,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.accent(context),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: AppTheme.label(
                                  fontSize: 11,
                                  color: AppTheme.accent(context),
                                ),
                              ),
                            ),
                      suffix: IconButton(
                        onPressed: () {
                          setState(() => _hidePassword = !_hidePassword);
                        },
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: AppTheme.muted(context),
                          size: 19,
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Minimum 6 characters.',
                        style: AppTheme.body(
                          fontSize: 10,
                          color: AppTheme.muted(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _acceptedTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                });
                              },
                              activeColor: AppTheme.accent(context),
                              side: BorderSide(
                                color: AppTheme.muted(context)
                                    .withValues(alpha: 0.65),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'I agree to University Research Terms & Privacy Policy',
                              style: AppTheme.body(
                                fontSize: 11,
                                color: AppTheme.muted(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _InlineAuthMessage(message: _errorMessage!),
                    ],
                    const SizedBox(height: 22),
                    _GradientButton(
                      label: _isSignUp
                          ? 'Create Account & Continue'
                          : 'Log In to Dashboard',
                      onPressed: _isLoading ? null : _submit,
                      isLoading: _isLoading && !_isGoogleLoading,
                    ),
                    const SizedBox(height: 14),
                    _OrDivider(color: AppTheme.muted(context)),
                    const SizedBox(height: 14),
                    _GoogleButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      isLoading: _isGoogleLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Back',
        style: IconButton.styleFrom(
          backgroundColor: isDark
              ? AppTheme.surface.withValues(alpha: 0.8)
              : AppTheme.lightSurface,
          foregroundColor: AppTheme.onCanvas(context),
          side: BorderSide(
            color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 19),
      ),
    );
  }
}

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({required this.isSignUp, required this.onChanged});

  final bool isSignUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.surface.withValues(alpha: 0.72)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          _AuthTab(
            label: 'Sign Up',
            selected: isSignUp,
            onTap: () => onChanged(true),
          ),
          _AuthTab(
            label: 'Log In',
            selected: !isSignUp,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              gradient: selected ? AppTheme.primaryGradient : null,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.22),
                        blurRadius: 9,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTheme.label(
                  fontSize: 12,
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.muted(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.validator,
    this.trailing,
    this.suffix,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? trailing;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.onCanvas(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTheme.label(
                  fontSize: 12,
                  color: AppTheme.muted(context),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onFieldSubmitted: onSubmitted,
          style: AppTheme.body(fontSize: 13, color: textColor),
          cursorColor: AppTheme.accent(context),
          decoration: _fieldDecoration(
            context,
            hint: hint,
            icon: icon,
            suffix: suffix,
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: color.withValues(alpha: 0.24))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OR CONTINUE WITH',
            style: AppTheme.label(
              fontSize: 10,
              color: color,
            ).copyWith(letterSpacing: 0.8),
          ),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.24))),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed, required this.isLoading});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppTheme.surface.withValues(alpha: 0.86) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: isLoading
                ? [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ]
                : [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CustomPaint(painter: _GoogleLogoPainter()),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: AppTheme.title(
                        fontSize: 14,
                        color: AppTheme.onCanvas(context),
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class _InlineAuthMessage extends StatelessWidget {
  const _InlineAuthMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(message, style: AppTheme.body(fontSize: 12, color: color)),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bluePath = Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10)
      ..lineTo(12, 10)
      ..lineTo(12, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
    canvas.drawPath(bluePath, blue);

    final greenPath = Path()
      ..moveTo(12, 23)
      ..cubicTo(14.97, 23, 17.46, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.1)
      ..lineTo(2.18, 14.1)
      ..lineTo(2.18, 16.94)
      ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
      ..close();
    canvas.drawPath(greenPath, green);

    final yellowPath = Path()
      ..moveTo(5.84, 14.09)
      ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.06)
      ..lineTo(2.18, 7.06)
      ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
      ..cubicTo(1, 13.78, 1.43, 15.45, 2.18, 16.94)
      ..lineTo(5.03, 14.72)
      ..lineTo(5.84, 14.09)
      ..close();
    canvas.drawPath(yellowPath, yellow);

    final redPath = Path()
      ..moveTo(12, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
      ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.06)
      ..lineTo(5.84, 9.9)
      ..cubicTo(6.71, 7.3, 9.14, 5.38, 12, 5.38)
      ..close();
    canvas.drawPath(redPath, red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Text(label, style: AppTheme.title(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: const Alignment(0.9, -1.05),
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppTheme.primary.withValues(alpha: isDark ? 0.28 : 0.16),
              AppTheme.primary.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final borderColor = isDark ? AppTheme.glassBorder : AppTheme.lightBorder;
  final accent = AppTheme.accent(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: borderColor),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: AppTheme.body(fontSize: 12, color: AppTheme.muted(context)),
    prefixIcon: Icon(icon, color: accent, size: 19),
    suffixIcon: suffix,
    filled: true,
    fillColor: isDark
        ? AppTheme.surface.withValues(alpha: 0.62)
        : AppTheme.lightSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent, width: 1.4),
    ),
  );
}
