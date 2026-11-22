import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_card.dart';
import '../widgets/theme_mode_button.dart';
import 'skills_screen.dart';

class RiasecQuizScreen extends StatefulWidget {
  const RiasecQuizScreen({
    super.key,
    required this.academicProfile,
    this.authService,
  });

  final StudentAcademicProfile academicProfile;
  final AuthService? authService;

  @override
  State<RiasecQuizScreen> createState() => _RiasecQuizScreenState();
}

class _RiasecQuizScreenState extends State<RiasecQuizScreen> {
  static const List<_RiasecQuestion> _questions = [
    _RiasecQuestion(
      code: 'R',
      category: 'Practical & Hands-On (Realistic)',
      icon: Icons.build_rounded,
      statement: 'I enjoy hands-on activities, assembling machinery, working with electronics, or building physical projects.',
    ),
    _RiasecQuestion(
      code: 'I',
      category: 'Analytical & Scientific (Investigative)',
      icon: Icons.science_rounded,
      statement: 'I enjoy analyzing experimental data, solving abstract mathematical puzzles, and understanding how scientific systems work.',
    ),
    _RiasecQuestion(
      code: 'A',
      category: 'Creative & Design (Artistic)',
      icon: Icons.palette_rounded,
      statement: 'I love designing visual layouts, sketching user interfaces, writing creatively, or expressing ideas visually.',
    ),
    _RiasecQuestion(
      code: 'S',
      category: 'People & Mentoring (Social)',
      icon: Icons.people_alt_rounded,
      statement: 'I find fulfillment in mentoring junior students, counselling peers, and organizing community workshops.',
    ),
    _RiasecQuestion(
      code: 'E',
      category: 'Leadership & Business (Enterprising)',
      icon: Icons.business_center_rounded,
      statement: 'I like pitching startup ideas, leading teams, marketing products, and taking financial initiatives.',
    ),
    _RiasecQuestion(
      code: 'C',
      category: 'Organized & Systematic (Conventional)',
      icon: Icons.checklist_rounded,
      statement: 'I prefer organized schedules, verifying spreadsheet financial calculations, and systematic data archiving.',
    ),
  ];

  static const List<String> _answers = [
    '1 - Strongly Enjoy',
    '2 - Enjoy',
    '3 - Neutral / Unsure',
    '4 - Dislike',
    '5 - Strongly Dislike',
  ];

  final List<int?> _scores = List<int?>.filled(_questions.length, null);
  int _questionIndex = 0;

  _RiasecQuestion get _question => _questions[_questionIndex];

  void _goBack() {
    if (_questionIndex > 0) {
      setState(() => _questionIndex--);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _continue() {
    if (_scores[_questionIndex] == null) {
      showAppSnackBar(context, 'Choose an answer to continue.');
      return;
    }

    if (_questionIndex < _questions.length - 1) {
      setState(() => _questionIndex++);
      return;
    }

    final riasecScores = <String, int>{
      for (var index = 0; index < _questions.length; index++)
        _questions[index].code: _scores[index]!,
    };
    Navigator.of(context).push<void>(
      _fadeSlideRoute(
        SkillsScreen(
          academicProfile: widget.academicProfile,
          riasecScores: riasecScores,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
              child: Row(
                children: [
                  _BackButton(onPressed: _goBack),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Step 2 of 3: Personality Fit',
                      style: AppTheme.label(
                        fontSize: 10,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ThemeModeButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_questionIndex + 1} of ${_questions.length}',
                        style: AppTheme.label(
                          fontSize: 11,
                          color: AppTheme.muted(context),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _question.category,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.label(
                            fontSize: 10,
                            color: AppTheme.accent(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _StepProgress(
                    value: (_questionIndex + 1) / _questions.length,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Career Interest Assessment',
                      style: AppTheme.heading(
                        fontSize: 23,
                        color: AppTheme.onCanvas(context),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Rate how naturally each statement reflects your interests.',
                      style: AppTheme.body(
                        fontSize: 12,
                        color: AppTheme.muted(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassCard(
                      isSelected: true,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.accent(context)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.accent(context)
                                    .withValues(alpha: 0.28),
                              ),
                            ),
                            child: Icon(
                              _question.icon,
                              color: AppTheme.accent(context),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _question.category,
                            style: AppTheme.label(
                              fontSize: 11,
                              color: AppTheme.accent(context),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '“${_question.statement}”',
                            style: AppTheme.title(
                              fontSize: 15,
                              color: AppTheme.onCanvas(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    for (var index = 0; index < _answers.length; index++) ...[
                      _AnswerChoice(
                        label: _answers[index],
                        selected:
                            _scores[_questionIndex] == _answers.length - index,
                        isDark: isDark,
                        onTap: () {
                          setState(
                            () => _scores[_questionIndex] =
                                _answers.length - index,
                          );
                        },
                      ),
                      if (index < _answers.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _goBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.onCanvas(context),
                      side: BorderSide(
                        color: isDark
                            ? AppTheme.glassBorder
                            : AppTheme.lightBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Previous',
                      style: AppTheme.label(
                        fontSize: 12,
                        color: AppTheme.onCanvas(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GradientButton(
                      label: _questionIndex == _questions.length - 1
                          ? 'Continue to Skills'
                          : 'Next Question',
                      onPressed: _continue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiasecQuestion {
  const _RiasecQuestion({
    required this.code,
    required this.category,
    required this.icon,
    required this.statement,
  });

  final String code;
  final String category;
  final IconData icon;
  final String statement;
}

class _AnswerChoice extends StatelessWidget {
  const _AnswerChoice({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      isSelected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.label(
                fontSize: 12,
                color: selected
                    ? AppTheme.accent(context)
                    : AppTheme.onCanvas(context),
              ),
            ),
          ),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected
                ? AppTheme.accent(context)
                : AppTheme.muted(context).withValues(alpha: isDark ? 0.7 : 0.8),
            size: 19,
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

    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: isDark ? AppTheme.surface : AppTheme.lightSurface,
        foregroundColor: AppTheme.onCanvas(context),
        side: BorderSide(
          color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 6,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.surface
            : AppTheme.lightBorder,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: const SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryLight, AppTheme.cyan],
                ),
              ),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.title(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route<void> _fadeSlideRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
