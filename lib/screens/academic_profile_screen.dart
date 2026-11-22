import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_theme.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import '../services/history_repository.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/account_menu_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/theme_mode_button.dart';
import 'history_screen.dart';
import 'riasec_quiz_screen.dart';
import 'saved_matches_screen.dart';

const Map<String, List<String>> academicSpecializationOptions = {
  'Matric': [
    'Science Group (Bio-Science)',
    'General Science Group (Computer Science)',
    'Arts / Humanities & Home Economics Group',
  ],
  'Intermediate': [
    'Pre-Engineering (Math, Physics, Chemistry)',
    'Pre-Medical (Biology, Physics, Chemistry)',
    'ICS (Computer Science, Math, Physics)',
    'I.Com (Commerce, Economics, Accounting)',
    'Humanities / Arts',
  ],
  'Bachelors': [
    'BS Software Engineering / Computer Science',
    'BE Electrical / Electronics Engineering',
    'BBA / BS Accounting & Finance',
    'BS Biotechnology / Microbiology',
    'BS Psychology / Social Sciences',
  ], };

class AcademicProfileScreen extends StatefulWidget {
  const AcademicProfileScreen({
    super.key,
    this.authService,
    this.historyRepository,
  });

  final AuthService? authService;
  final HistoryRepository? historyRepository;

  @override
  State<AcademicProfileScreen> createState() => _AcademicProfileScreenState();
}

class _AcademicProfileScreenState extends State<AcademicProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController(text: '84.5');
  late final HistoryRepository _historyRepository =
      widget.historyRepository ??
      HistoryRepository(authService: widget.authService);

  String _educationLevel = 'Intermediate';
  String? _specialization = 'Pre-Engineering (Math, Physics, Chemistry)';
  AcademicScoreType _scoreType = AcademicScoreType.percentage;

  List<String> get _currentSpecializations {
    return (academicSpecializationOptions[_educationLevel] ?? const <String>[])
        .toSet()
        .toList(growable: false);
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  void _selectEducation(String level) {
    final options = (academicSpecializationOptions[level] ?? const <String>[])
        .toSet()
        .toList(growable: false);
    setState(() {
      if (level == 'Bachelors' && _educationLevel != 'Bachelors') {
        _scoreType = AcademicScoreType.cgpa;
        _scoreController.clear();
      }
      _educationLevel = level;
      _specialization = options.isEmpty ? null : options.first;
    });
  }

  void _selectScoreType(AcademicScoreType type) {
    if (_educationLevel == 'Bachelors' &&
        type == AcademicScoreType.percentage) {
      if (_scoreType != AcademicScoreType.cgpa) {
        setState(() {
          _scoreType = AcademicScoreType.cgpa;
          _scoreController.clear();
        });
      }
      showAppSnackBar(
        context,
        'For Bachelors, please enter CGPA only (out of 4.0).',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _scoreType = type;
      _scoreController.text = type == AcademicScoreType.percentage
          ? '84.5'
          : '3.52';
    });
  }

  void _viewHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: HistoryScreen(
              repository: _historyRepository,
              showBackButton: true,
              onViewMatches: (record) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      backgroundColor: Theme.of(context)
                          .scaffoldBackgroundColor,
                      body: SafeArea(
                        child: SavedMatchesScreen(
                          record: record,
                          showBackButton: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
              onStartAssessment: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }

  void _continue() {
    if (_educationLevel == 'Bachelors' &&
        _scoreType != AcademicScoreType.cgpa) {
      showAppSnackBar(
        context,
        'For Bachelors, please enter CGPA only (out of 4.0).',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final specialization = _specialization;
    if (specialization == null) {
      showAppSnackBar(context, 'Select a specialization to continue.');
      return;
    }

    final profile = StudentAcademicProfile(
      educationLevel: _educationLevel,
      specialization: specialization,
      academicScore: double.parse(_scoreController.text),
      scoreType: _scoreType,
    );
    Navigator.of(context).push<void>(
      _fadeSlideRoute(
        RiasecQuizScreen(
          academicProfile: profile,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
                child: Row(
                  key: const ValueKey('academic-profile-header'),
                  children: [
                    _BackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _StepBadge(
                        label: 'Step 1 of 3: Academics',
                        compactLabel: 'Step 1 of 3',
                        color: AppTheme.cyan,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AccountMenuButton(authService: widget.authService),
                    const SizedBox(width: 6),
                    _HistoryButton(onPressed: _viewHistory),
                    const SizedBox(width: 6),
                    const ThemeModeButton(),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _StepProgress(value: 1 / 3),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EducationBanner(),
                      const SizedBox(height: 18),
                      Text(
                        'Your Academic Profile',
                        style: AppTheme.heading(
                          fontSize: 24,
                          color: AppTheme.onCanvas(context),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your grades factor into career recommendations.',
                        style: AppTheme.body(
                          fontSize: 13,
                          color: AppTheme.muted(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Current Education Level',
                        style: _fieldLabel(context),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: _EducationCard(
                              title: 'Matric',
                              subtitle: 'SSC 9–10th',
                              icon: Icons.school_rounded,
                              selected: _educationLevel == 'Matric',
                              onTap: () => _selectEducation('Matric'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _EducationCard(
                              title: 'Intermediate',
                              subtitle: 'HSSC 11–12th',
                              icon: Icons.menu_book_rounded,
                              selected: _educationLevel == 'Intermediate',
                              onTap: () => _selectEducation('Intermediate'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _EducationCard(
                              title: 'Bachelors',
                              subtitle: 'Undergrad',
                              icon: Icons.account_balance_rounded,
                              selected: _educationLevel == 'Bachelors',
                              onTap: () => _selectEducation('Bachelors'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Major Field / Study Group',
                        style: _fieldLabel(context),
                      ),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_educationLevel),
                        initialValue:

_currentSpecializations.contains(_specialization)
                            ? _specialization
                            : null,
                        isExpanded: true,
                        hint: Text(
                          'Select a specialization',
                          style: AppTheme.body(
                            fontSize: 13,
                            color: AppTheme.muted(context),
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.muted(context),
                        ),
                        dropdownColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.surface
                            : AppTheme.lightSurface,
                        style: AppTheme.body(
                          fontSize: 13,
                          color: AppTheme.onCanvas(context),
                        ),
                        decoration: _inputDecoration(context),
                        items: _currentSpecializations
                            .map(
                              (specialization) => DropdownMenuItem(
                                value: specialization,
                                child: Text(
                                  specialization,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select a specialization.' : null,
                        onChanged: (value) {
                          setState(() => _specialization = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Academic Score',
                              style: _fieldLabel(context),
                            ),
                          ),
                          _ScoreTypeToggle(
                            scoreType: _scoreType,
                            onChanged: _selectScoreType,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _scoreController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        style: AppTheme.title(
                          fontSize: 15,
                          color: AppTheme.onCanvas(context),
                        ),
                        decoration: _inputDecoration(context).copyWith(
                          suffixText: _scoreType == AcademicScoreType.cgpa
                              ? '/ 4.0'
                              : '%',
                          suffixStyle: AppTheme.label(
                            fontSize: 13,
                            color: AppTheme.accent(context),
                          ),
                        ),
                        validator: (value) {
                          final score = double.tryParse(value ?? '');
                          final maximum = _scoreType == AcademicScoreType.cgpa
                              ? 4
                              : 100;
                          if (score == null || score < 0 || score > maximum) {
                            return _scoreType == AcademicScoreType.cgpa
                                ? 'Enter a CGPA between 0 and 4.'
                                : 'Enter a percentage between 0 and 100.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Based on Board / University official marksheets.',
                        style: AppTheme.body(
                          fontSize: 10,
                          color: AppTheme.muted(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _GradientButton(label: 'Continue', onPressed: _continue),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EducationBanner extends StatelessWidget {
  const _EducationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0764), Color(0xFF172554)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryLight.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppTheme.cyan,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Text('Educational Milestones', style: AppTheme.title(fontSize: 14)),
          const Spacer(),
          Icon(
            Icons.auto_graph_rounded,
            size: 35,
            color: Colors.white.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}

class _EducationCard extends StatelessWidget {
  const _EducationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      isSelected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: selected
                ? AppTheme.accent(context)
                : AppTheme.muted(context),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.label(
              fontSize: 10,
              color: AppTheme.onCanvas(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.body(fontSize: 9, color: AppTheme.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _ScoreTypeToggle extends StatelessWidget {
  const _ScoreTypeToggle({required this.scoreType, required this.onChanged});

  final AcademicScoreType scoreType;
  final ValueChanged<AcademicScoreType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.surface
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.glassBorder
              : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          _ScoreTypeButton(
            label: 'Percentage %',
            selected: scoreType == AcademicScoreType.percentage,
            onTap: () => onChanged(AcademicScoreType.percentage),
          ),
          _ScoreTypeButton(
            label: 'CGPA',
            selected: scoreType == AcademicScoreType.cgpa,
            onTap: () => onChanged(AcademicScoreType.cgpa),
          ),
        ],
      ),
    );
  }
}

class _ScoreTypeButton extends StatelessWidget {
  const _ScoreTypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.accent(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: AppTheme.label(
              fontSize: 9,
              color: selected ? Colors.white : AppTheme.muted(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.surface
            : AppTheme.lightSurface,
        foregroundColor: AppTheme.onCanvas(context),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.glassBorder
              : AppTheme.lightBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: 'History',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppTheme.lightSurface,
        foregroundColor: AppTheme.onCanvas(context),
        side: BorderSide(
          color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: const Icon(Icons.history_rounded),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.label,
    required this.compactLabel,
    required this.color,
  });
  final String label;
  final String compactLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayLabel = constraints.maxWidth < 130 ? compactLabel : label;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayLabel,
              maxLines: 1,
              softWrap: false,
              style: AppTheme.label(fontSize: 10, color: color),
            ),
          ),
        );
      },
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
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final borderColor = isDark ? AppTheme.glassBorder : AppTheme.lightBorder;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: borderColor),
  );

  return InputDecoration(
    filled: true,
    fillColor: isDark ? AppTheme.surface : AppTheme.lightSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.accent(context), width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.rose.withValues(alpha: 0.8)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.rose, width: 1.4),
    ),
  );
}

TextStyle _fieldLabel(BuildContext context) {
  return AppTheme.label(fontSize: 12, color: AppTheme.muted(context));
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
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
              children: [Text(label, style: AppTheme.title(fontSize: 14))],
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