import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../models/student_profile.dart';
import 'academic_profile_screen.dart';
import 'history_screen.dart';
import 'saved_matches_screen.dart';
import '../services/auth_service.dart';
import '../services/history_repository.dart';
import '../services/recommendation_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/account_menu_button.dart';
import '../widgets/theme_mode_button.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.academicProfile,
    required this.riasecScores,
    required this.skillRatings,
    this.authService,
    this.recommendationService,
  });

  final StudentAcademicProfile academicProfile;
  final Map<String, int> riasecScores;
  final Map<String, int> skillRatings;
  final AuthService? authService;
  final RecommendationService? recommendationService;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final RecommendationService _recommendationService =
      widget.recommendationService ?? const RecommendationService();
  final ScrollController _matchesScrollController = ScrollController();
  final ScrollController _roadmapScrollController = ScrollController();
  late Future<List<CareerRecommendation>> _recommendationsFuture;
  late final HistoryRepository _historyRepository = HistoryRepository(
    authService: widget.authService,
  );
  Future<AssessmentRecord?>? _assessmentRecordFuture;
  bool _isSaving = false;
  bool _isSavingLearningPlan = false;
  int _selectedTabIndex = 1;
  String? _selectedRadarCareerTitle;
  String? _roadmapCareerTitle;
  AssessmentRecord? _selectedHistoryRecord;

  bool get _isMatric =>
      widget.academicProfile.educationLevel.trim().toLowerCase() == 'matric';

  bool get _isBachelors =>
      widget.academicProfile.educationLevel.trim().toLowerCase() == 'bachelors';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _matchesScrollController.dispose();
    _roadmapScrollController.dispose();
    super.dispose();
  }

  void _loadRecommendations() {
    _recommendationsFuture = _recommendationService.recommend(
      academicProfile: widget.academicProfile,
      riasecScores: widget.riasecScores,
      skillRatings: widget.skillRatings,
    );
    _assessmentRecordFuture = _createAssessmentRecord(_recommendationsFuture);
    unawaited(_saveAssessmentToHistory(_assessmentRecordFuture!));
  }

  Future<AssessmentRecord?> _createAssessmentRecord(
    Future<List<CareerRecommendation>> recommendationsFuture,
  ) async {
    final recommendations = await recommendationsFuture;
    if (recommendations.isEmpty) return null;
    final score = widget.academicProfile.scoreType == AcademicScoreType.cgpa
        ? widget.academicProfile.academicScore * 25
        : widget.academicProfile.academicScore;
    return AssessmentRecord(
      id: _historyRepository.createId(),
      createdAt: DateTime.now(),
      educationLevel: widget.academicProfile.educationLevel,
      group: widget.academicProfile.specialization,
      percentage: score,
      riasecScores: widget.riasecScores,
      skills: widget.skillRatings,
      top5: [
        for (final recommendation in recommendations)
          AssessmentCareerMatch(
            title: recommendation.title,
            matchPercent: recommendation.matchPercent,
          ),
      ],
      topCareer: recommendations.first.title,
      engine: recommendations.first.engineName,
    );
  }

  Future<void> _saveAssessmentToHistory(
    Future<AssessmentRecord?> recordFuture,
  ) async {
    try {
      final record = await recordFuture;
      if (record != null) await _historyRepository.save(record);
    } catch (error) {
      debugPrint('Could not save assessment history: $error');
    }
  }

  Future<void> _saveResult() async {
    setState(() => _isSaving = true);
    try {
      final record = await _assessmentRecordFuture;
      if (record == null) {
        if (mounted) _showMessage('No assessment is available to save.');
        return;
      }
      final synced = await _historyRepository.save(record);
      if (!mounted) return;
      _showMessage(
        synced ? 'Saved to your account' : 'Saved on this device',
        icon: synced ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      debugPrint('Could not save career results: $error');
      _showMessage('Could not save results. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(
    String message, {
    IconData icon = Icons.auto_awesome_rounded,
  }) {
    showAppSnackBar(context, message, icon: icon);
  }

  void _retakeAssessment() {
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => AcademicProfileScreen(authService: widget.authService),
      ),
      (route) => route.isFirst,
    );
  }

  void _selectTab(int index) {
    if (index == 0) {
      _retakeAssessment();
      return;
    }
    setState(() => _selectedTabIndex = index);
  }

  void _viewRoadmapFor(CareerRecommendation recommendation) {
    setState(() {
      _roadmapCareerTitle = recommendation.title;
      _selectedTabIndex = 2;
    });
  }

  void _viewHistoryMatches(AssessmentRecord record) {
    setState(() {
      _selectedHistoryRecord = record;
      _selectedTabIndex = 1;
    });
  }

  Widget _buildSavedMatchesTab(BuildContext context, AssessmentRecord record) {
    return SavedMatchesScreen(
      record: record,
    );
  }

  Future<void> _saveLearningPlan() async {
    if (_isSavingLearningPlan) return;
    setState(() => _isSavingLearningPlan = true);
    try {
      final recommendations = await _recommendationsFuture;
      final recommendation = recommendations.firstWhere(
        (item) => item.title == _roadmapCareerTitle,
        orElse: () => recommendations.first,
      );
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        'saved_career_learning_plan',
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'career': recommendation.toJson(),
          'fitReasons': _roadmapFitReasons(recommendation),
          'skillGaps': recommendation.skillGaps
              .map((gap) => gap.toJson())
              .toList(),
        }),
      );
      if (!mounted) return;
      _showMessage(
        saved
            ? '${recommendation.title} saved to your learning plan.'
            : 'Unable to save the learning plan.',
      );
    } on Exception catch (error) {
      if (!mounted) return;
      _showMessage('Could not save the learning plan: $error');
    } finally {
      if (mounted) setState(() => _isSavingLearningPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.background : AppTheme.lightBackground,
          gradient: isDark
              ? const RadialGradient(
                  center: Alignment(0, -1.05),
                  radius: 1.45,
                  colors: [Color(0xFF1E1145), AppTheme.background],
                  stops: [0, 0.72],
                )
              : null,
        ),
        child: SafeArea(
          child: _selectedTabIndex == 3
              ? HistoryScreen(
                  repository: _historyRepository,
                  onViewMatches: _viewHistoryMatches,
                  onStartAssessment: _retakeAssessment,
                )
              : _selectedTabIndex == 1 && _selectedHistoryRecord != null
              ? _buildSavedMatchesTab(context, _selectedHistoryRecord!)
              : FutureBuilder<List<CareerRecommendation>>(
                  future: _recommendationsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(
                        message: snapshot.error.toString(),
                        onRetry: () => setState(_loadRecommendations),
                      );
                    }
                    final recommendations = snapshot.data ?? const [];
                    if (recommendations.isEmpty) {
                      return _ErrorState(
                        message: 'No careers could be matched from the local dataset.',
                        onRetry: () => setState(_loadRecommendations),
                      );
                    }

                    final roadmapRecommendation = recommendations.firstWhere(
                      (recommendation) =>
                          recommendation.title == _roadmapCareerTitle,
                      orElse: () => recommendations.first,
                    );
                    return _selectedTabIndex == 2
                        ? _buildRoadmapTab(context, roadmapRecommendation)
                        : _buildMatchesTab(context, recommendations);
                  },
                ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedTabIndex == 2)
            _SaveLearningPlanButton(
              isSaving: _isSavingLearningPlan,
              onPressed: _saveLearningPlan,
            ),
          _DashboardNavigationBar(
            selectedIndex: _selectedTabIndex,
            onSelected: _selectTab,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesTab(
    BuildContext context,
    List<CareerRecommendation> recommendations,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedRadarCareer = recommendations.firstWhere(
      (recommendation) => recommendation.title == _selectedRadarCareerTitle,
      orElse: () => recommendations.first,
    );
    return ListView(
      key: const ValueKey('career-matches-list'),
      controller: _matchesScrollController,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      children: [
        _DashboardHeader(
          title: _isMatric ? 'Recommended Study Paths' : 'Your Career Matches',
          subtitle: switch (recommendations.first.engineName) {
            RecommendationService.tfliteEngineName =>
              RecommendationService.tfliteSubtitle,
            RecommendationService.streamRulesEngineName =>
              RecommendationService.streamRulesSubtitle,
            _ => RecommendationService.fallbackSubtitle,
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Save to History',
                onPressed: _isSaving ? null : _saveResult,
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.surface.withValues(alpha: 0.8)
                      : AppTheme.lightSurface,
                  foregroundColor: AppTheme.accent(context),
                  side: BorderSide(
                    color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_border_rounded, size: 18),
              ),
              AccountMenuButton(authService: widget.authService),
              const ThemeModeButton(),
            ],
          ),
        ),
        const SizedBox(height: 13),
        _TopCareerHero(
          recommendation: recommendations.first,
          riasecScores: widget.riasecScores,
          isBachelors: _isBachelors,
          tagLabel: _isMatric ? '#1 TOP STUDY PATH' : '#1 TOP RECOMMENDATION',
          onViewRoadmap: () => _viewRoadmapFor(recommendations.first),
        ),
        const SizedBox(height: 14),
        RadarAlignmentCard(recommendation: selectedRadarCareer),
        const SizedBox(height: 16),
        Text(
          _isMatric ? 'Other Study Paths' : 'Other Recommended Matches',
          style: AppTheme.label(
            fontSize: 11,
            color: AppTheme.muted(context),
          ).copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        for (var index = 1; index < recommendations.length; index++) ...[
          _RecommendationCard(
            recommendation: recommendations[index],
            rank: index + 1,
            isBachelors: _isBachelors,
            onViewSkillGap: () => _viewRoadmapFor(recommendations[index]),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _selectedRadarCareerTitle = recommendations[index].title;
                } else if (_selectedRadarCareerTitle ==
                    recommendations[index].title) {
                  _selectedRadarCareerTitle = null;
                }
              });
            },
          ),
          if (index < recommendations.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 11),
        _ResultActions(
          onViewHistory: () => _selectTab(3),
          onRetake: _retakeAssessment,
        ),
      ],
    );
  }

  Widget _buildRoadmapTab(
    BuildContext context,
    CareerRecommendation recommendation,
  ) {
    final skillGaps = sortCareerSkillGaps(recommendation.skillGaps);
    final gapsToBuild = skillGaps.where((skill) => skill.difference > 0).length;
    final biggestGap = skillGaps.where((skill) => skill.difference > 0).toList()
      ..sort((first, second) {
        final differenceOrder = second.difference.compareTo(first.difference);
        if (differenceOrder != 0) return differenceOrder;
        return first.skillName.toLowerCase().compareTo(
          second.skillName.toLowerCase(),
        );
      });
    final firstStep = biggestGap.isNotEmpty
        ? (
            title: 'Build ${biggestGap.first.skillName}',
            detail:
                'Start with ${biggestGap.first.skillName}: your current '
                'rating is ${biggestGap.first.currentLevel}/5 versus an '
                'the career requirement of '
                '${biggestGap.first.requiredLevel}/5.',
          )
        : (
            title: 'Strengthen your foundations',
            detail: skillGaps.isEmpty
                ? 'The dataset lists no skills for this career yet. Explore the learning resources and build a project to discover your strengths.'
                : 'Your ratings meet or exceed the inferred benchmarks for the listed skills. Reinforce them with a focused practice project.',
          );
    final nextGap = biggestGap.length > 1 ? biggestGap[1] : null;
    final List<({String title, String detail, IconData icon})> steps = _isMatric
        ? [
            (
              title: biggestGap.isEmpty
                  ? 'Strengthen your core subjects'
                  : 'Strengthen ${biggestGap.first.skillName}',
              detail: biggestGap.isEmpty
                  ? 'Review the core subjects for '
                        '${recommendation.subtitle ?? recommendation.title} '
                        'and practise the areas you find most challenging.'
                  : 'Your largest current gap is '
                        '${biggestGap.first.skillName} '
                        '(${biggestGap.first.currentLevel}/5; '
                        '${biggestGap.first.requiredLevel}/5 needed). '
                        'Start there to build a foundation for '
                        '${recommendation.subtitle ?? recommendation.title}.',
              icon: Icons.menu_book_rounded,
            ),
            (
              title: biggestGap.length < 2
                  ? 'Review path prerequisites'
                  : 'Build ${biggestGap[1].skillName}',
              detail: biggestGap.length < 2
                  ? 'Revisit the prerequisite subjects for '
                        '${recommendation.subtitle ?? recommendation.title} '
                        'and make sure the key concepts are clear.'
                  : 'Give extra practice to ${biggestGap[1].skillName} '
                        '(${biggestGap[1].currentLevel}/5 today) with '
                        'short, regular exercises.',
              icon: Icons.edit_note_rounded,
            ),
            (
              title: 'Create a weekly study routine',
              detail: biggestGap.isEmpty
                  ? 'Keep reviewing the main subjects for '
                        '${recommendation.subtitle ?? recommendation.title} '
                        'and track the topics you have mastered.'
                  : 'Schedule weekly practice for '
                        '${biggestGap.first.skillName}'
                        '${biggestGap.length > 1 ? ' and ${biggestGap[1].skillName}' : ''}, '
                        'then check your progress against the path requirements.',
              icon: Icons.event_note_rounded,
            ),
          ]
        : [
            (
              title: firstStep.title,
              detail: firstStep.detail,
              icon: Icons.flag_rounded,
            ),
            (
              title: nextGap == null
                  ? 'Practice with a focused project'
                  : 'Practice ${nextGap.skillName}',
              detail: nextGap == null
                  ? biggestGap.isEmpty
                        ? 'Apply your current skills to a small project related to ${recommendation.title}.'
                        : 'Use a small ${recommendation.title} project to practice ${biggestGap.first.skillName}.'
                  : 'Apply ${nextGap.skillName} in a small project related to ${recommendation.title}.',
              icon: Icons.handyman_rounded,
            ),
            (
              title: biggestGap.isEmpty
                  ? 'Build your portfolio'
                  : 'Show your ${biggestGap.first.skillName} progress',
              detail: biggestGap.isEmpty
                  ? 'Document your project, explain the decisions you made, and share the result.'
                  : 'Document how you used ${biggestGap.first.skillName}, explain your decisions, and share the result.',
              icon: Icons.workspace_premium_rounded,
            ),
          ];

    return ListView(
      key: const ValueKey('career-roadmap-list'),
      controller: _roadmapScrollController,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      children: [
        _DashboardHeader(
          title: _isMatric ? 'Study Path Roadmap' : 'Career Roadmap',
          subtitle: _isMatric
              ? 'Subject-strengthening plan for '
                    '${recommendation.subtitle ?? recommendation.title}'
              : 'Skill-gap plan for ${recommendation.title}',
          trailing: const ThemeModeButton(),
        ),
        const SizedBox(height: 14),
        _TopCareerHero(
          recommendation: recommendation,
          riasecScores: widget.riasecScores,
          onViewRoadmap: () => _viewRoadmapFor(recommendation),
          isBachelors: _isBachelors,
          compact: true,
          tagLabel: _isMatric ? 'SELECTED STUDY PATH' : 'SELECTED CAREER',
        ),
        const SizedBox(height: 16),
        _WhyFitsCard(reasons: _roadmapFitReasons(recommendation)),
        const SizedBox(height: 16),
        _SkillGapAnalysis(skillGaps: skillGaps, gapCount: gapsToBuild),
        const SizedBox(height: 16),
        const _SectionHeading(
          icon: Icons.route_rounded,
          title: '3-Step Roadmap',
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < steps.length; index++) ...[
          _RoadmapStepCard(
            number: index + 1,
            title: steps[index].title,
            detail: steps[index].detail,
            icon: steps[index].icon,
            isLast: index == steps.length - 1,
          ),
          if (index < steps.length - 1) const SizedBox(height: 9),
        ],
        const SizedBox(height: 16),
        _SectionHeading(
          icon: Icons.school_rounded,
          title: 'Free Learning Resources',
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (final resource in recommendation.learningResources)
                _ResourceLine(resource: resource),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _roadmapFitReasons(CareerRecommendation recommendation) {
    return recommendation.reasons;
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.heading(
                  fontSize: 18,
                  color: AppTheme.onCanvas(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.body(
                  fontSize: 10,
                  color: AppTheme.muted(context),
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _TopCareerHero extends StatelessWidget {
  const _TopCareerHero({
    required this.recommendation,
    required this.riasecScores,
    required this.onViewRoadmap,
    required this.isBachelors,
    this.tagLabel = '#1 TOP RECOMMENDATION',
    this.compact = false,
  });

  final CareerRecommendation recommendation;
  final Map<String, int> riasecScores;
  final VoidCallback onViewRoadmap;
  final bool isBachelors;
  final String tagLabel;
  final bool compact;

  static const Map<String, String> _interestLabels = {
    'R': 'Realistic',
    'I': 'Investigative',
    'A': 'Artistic',
    'S': 'Social',
    'E': 'Enterprising',
    'C': 'Conventional',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rankedInterests = riasecScores.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    final interestNames = rankedInterests
        .take(2)
        .map((entry) => _interestLabels[entry.key] ?? entry.key)
        .toList();
    final interestSummary = interestNames.isEmpty
        ? 'Career profile'
        : interestNames.join(' & ');
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final supportingColor = isDark
        ? const Color(0xFFD8B4FE)
        : const Color(0xFF312E81);
    final badgeColor = isDark ? AppTheme.cyan : const Color(0xFF0E7490);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF581C87), Color(0xFF1E1B4B), Color(0xFF0F172A)]
              : const [Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppTheme.primaryLight.withValues(alpha: 0.45)
              : const Color(0xFFC084FC),
          width: isDark ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroTag(label: tagLabel, isDark: isDark),
              const Spacer(),
              _MatchBadge(
                percent: recommendation.matchPercent,
                color: badgeColor,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF581C87), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: AppTheme.cyan.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  _careerIcon(recommendation.title),
                  color: isDark ? AppTheme.cyan : Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.heading(fontSize: 18, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recommendation.leadsTo.isEmpty
                          ? 'High $interestSummary Fit'
                          : isBachelors
                          ? 'Career matched to your interests'
                          : 'Study path matched to your interests',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.label(
                        fontSize: 10,
                        color: supportingColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.reasons.first,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: 11,
              color: isDark ? const Color(0xFFE2E8F0) : supportingColor,
            ),
          ),
          if (recommendation.leadsTo.isNotEmpty) ...[
            const SizedBox(height: 9),
            _LeadsToChips(careers: recommendation.leadsTo),
          ],
          const SizedBox(height: 10),
          _MatchProgress(
            percent: recommendation.matchPercent,
            color: isDark ? AppTheme.cyan : AppTheme.lightPrimary,
          ),
          if (recommendation.missingSkills.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in recommendation.missingSkills.take(2))
                  _SkillGapChip(label: skill),
              ],
            ),
          ],
          const SizedBox(height: 11),
          Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppTheme.lightPrimary.withValues(alpha: 0.16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile: $interestSummary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.label(
                    fontSize: 9,
                    color: isDark
                        ? const Color(0xFFD8B4FE)
                        : const Color(0xFF4C1D95),
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onViewRoadmap,
                  style: TextButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white
                        : AppTheme.lightPrimary,
                    foregroundColor: isDark
                        ? const Color(0xFF0F172A)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    textStyle: AppTheme.label(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    ),
                  ),
                  child: Text(
                    recommendation.leadsTo.isEmpty
                        ? 'View Skill Gap'
                        : isBachelors
                        ? 'View Skill Plan'
                        : 'View Study Plan',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static IconData _careerIcon(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('engineer') || normalized.contains('developer')) {
      return Icons.code_rounded;
    }
    if (normalized.contains('scientist') || normalized.contains('research')) {
      return Icons.science_rounded;
    }
    if (normalized.contains('counselor') || normalized.contains('professor')) {
      return Icons.psychology_rounded;
    }
    if (normalized.contains('account') || normalized.contains('financial')) {
      return Icons.account_balance_rounded;
    }
    if (normalized.contains('sales') || normalized.contains('marketing')) {
      return Icons.campaign_rounded;
    }
    if (normalized.contains('data') || normalized.contains('analyst')) {
      return Icons.analytics_rounded;
    }
    return Icons.work_outline_rounded;
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.primary.withValues(alpha: 0.2)
            : const Color(0xFFDDD6FE),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isDark
              ? AppTheme.primaryLight.withValues(alpha: 0.35)
              : const Color(0xFFA78BFA),
        ),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          fontSize: 8,
          color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF5B21B6),
        ).copyWith(letterSpacing: 0.55),
      ),
    );
  }
}

class _ChartTag extends StatelessWidget {
  const _ChartTag({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          fontSize: 8,
          color: isDark ? AppTheme.cyan : const Color(0xFF0E7490),
        ),
      ),
    );
  }
}

class _DashboardNavigationBar extends StatelessWidget {
  const _DashboardNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _destinations = [
    (label: 'Assess', icon: Icons.assignment_outlined),
    (label: 'Matches', icon: Icons.work_outline_rounded),
    (label: 'Roadmap', icon: Icons.map_outlined),
    (label: 'History', icon: Icons.history_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : AppTheme.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppTheme.lightBorder,
            ),
          ),
        ),
        child: Row(
          children: [
            for (var index = 0; index < _destinations.length; index++)
              Expanded(
                child: _NavigationDestination(
                  label: _destinations[index].label,
                  icon: _destinations[index].icon,
                  selected: selectedIndex == index,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationDestination extends StatelessWidget {
  const _NavigationDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accent(context) : AppTheme.muted(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.label(fontSize: 9, color: color)),
          ],
        ),
      ),
    );
  }
}

class _RoadmapStepCard extends StatelessWidget {
  const _RoadmapStepCard({
    required this.number,
    required this.title,
    required this.detail,
    required this.icon,
    required this.isLast,
  });

  final int number;
  final String title;
  final String detail;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppTheme.accent(context)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $number${isLast ? ' · FINAL' : ''}',
                  style: AppTheme.label(
                    fontSize: 8,
                    color: AppTheme.accent(context),
                  ).copyWith(letterSpacing: 0.7),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: AppTheme.title(
                    fontSize: 12,
                    color: AppTheme.onCanvas(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: AppTheme.body(
                    fontSize: 10,
                    color: AppTheme.muted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyFitsCard extends StatelessWidget {
  const _WhyFitsCard({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.primaryLight : const Color(0xFF7E22CE);
    return GlassCard(
      radius: 14,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isDark
                ? [
                    AppTheme.primary.withValues(alpha: 0.22),
                    const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  ]
                : const [Color(0xFFFAF5FF), Color(0xFFEDE9FE)],
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology_rounded,
                            color: accent,
                            size: 17,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Why This Fits Your Profile',
                              style: AppTheme.title(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFFD8B4FE)
                                    : const Color(0xFF581C87),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      for (final reason in reasons)
                        _BulletLine(
                          icon: Icons.check_rounded,
                          color: isDark
                              ? AppTheme.cyan
                              : const Color(0xFF0284C7),
                          text: reason,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillGapAnalysis extends StatelessWidget {
  const _SkillGapAnalysis({required this.skillGaps, required this.gapCount});

  final List<CareerSkillGap> skillGaps;
  final int gapCount;

  @override
  Widget build(BuildContext context) {
    final skillsWithGaps = skillGaps
        .where((skill) => skill.difference > 0)
        .toList();
    final counterStatus = skillsWithGaps.isEmpty
        ? SkillGapStatus.matchedStrength
        : skillsWithGaps.first.status;
    final counterColor = _skillGapStatusColor(context, counterStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 7,
          children: [
            const _SectionHeading(
              icon: Icons.track_changes_rounded,
              title: 'Skill Gap Analysis',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: counterColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: counterColor.withValues(alpha: 0.24)),
              ),
              child: Text(
                '$gapCount Gaps to Build',
                style: AppTheme.label(fontSize: 9, color: counterColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Based on expert-defined career profiles. Levels are estimates.',
          style: AppTheme.body(fontSize: 9, color: AppTheme.muted(context)),
        ),
        const SizedBox(height: 9),
        if (skillGaps.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(13),
            radius: 13,
            child: Text(
              'No skill-gap cards are available for this career.',
              style: AppTheme.body(
                fontSize: 10,
                color: AppTheme.muted(context),
              ),
            ),
          )
        else
          for (var index = 0; index < skillGaps.length; index++) ...[
            _SkillGapCard(skillGap: skillGaps[index]),
            if (index < skillGaps.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _SkillGapCard extends StatelessWidget {
  const _SkillGapCard({required this.skillGap});

  final CareerSkillGap skillGap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _skillGapStatusColor(context, skillGap.status);
    final progress = (skillGap.currentLevel / skillGap.requiredLevel)
        .clamp(0.0, 1.0)
        .toDouble();

    return GlassCard(
      radius: 13,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusColor, width: 4),
            top: BorderSide(color: statusColor.withValues(alpha: 0.12)),
            right: BorderSide(color: statusColor.withValues(alpha: 0.12)),
            bottom: BorderSide(color: statusColor.withValues(alpha: 0.12)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      skillGap.skillName,
                      style: AppTheme.title(
                        fontSize: 11,
                        color: AppTheme.onCanvas(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: ValueKey('skill-gap-status-${skillGap.skillName}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _skillGapStatusLabel(skillGap.status),
                      style: AppTheme.label(fontSize: 8, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _SkillLevelLine(
                    label: 'Current',
                    level: skillGap.currentLevel,
                  ),
                  _SkillLevelLine(
                    label: 'Required',
                    level: skillGap.requiredLevel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppTheme.muted(context)
                      .withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillLevelLine extends StatelessWidget {
  const _SkillLevelLine({required this.label, required this.level});

  final String label;
  final int level;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.muted(context);
    return Text.rich(
      TextSpan(
        style: AppTheme.body(fontSize: 9, color: color),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: '${_skillLevelLabel(level)} ($level/5)',
            style: AppTheme.label(
              fontSize: 9,
              color: AppTheme.onCanvas(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveLearningPlanButton extends StatelessWidget {
  const _SaveLearningPlanButton({
    required this.isSaving,
    required this.onPressed,
  });

  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('save-learning-plan'),
              onTap: isSaving ? null : onPressed,
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                height: 46,
                child: Center(
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save to My Learning Plan',
                          style: AppTheme.label(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _skillGapStatusColor(BuildContext context, SkillGapStatus status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    SkillGapStatus.needsAttention =>
      isDark ? AppTheme.rose : const Color(0xFFDC2626),
    SkillGapStatus.developing =>
      isDark ? AppTheme.amber : const Color(0xFFB45309),
    SkillGapStatus.matchedStrength =>
      isDark ? AppTheme.emerald : const Color(0xFF047857),
  };
}

String _skillGapStatusLabel(SkillGapStatus status) {
  return switch (status) {
    SkillGapStatus.needsAttention => 'Needs Attention',
    SkillGapStatus.developing => 'Developing',
    SkillGapStatus.matchedStrength => 'Matched Strength',
  };
}

String _skillLevelLabel(int level) {
  return switch (level) {
    0 => 'Not rated yet',
    1 => 'Beginner',
    2 => 'Elementary',
    3 => 'Intermediate',
    4 => 'Proficient',
    _ => 'Advanced',
  };
}

@visibleForTesting
class RadarAlignmentCard extends StatelessWidget {
  const RadarAlignmentCard({required this.recommendation});

  final CareerRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final axisColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF334155);
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFCBD5E1);
    final angleColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE2E8F0);

    return GlassCard(
      key: const ValueKey('radar-alignment-card'),
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar_rounded, color: AppTheme.primaryLight, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vector Alignment Analysis',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.title(
                    fontSize: 12,
                    color: AppTheme.onCanvas(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ChartTag(label: 'fl_chart', isDark: isDark),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Student Vector vs ${recommendation.title} Benchmark',
            key: const ValueKey('radar-chart-subtitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const sideLabelWidth = 88.0;
              const topLabelWidth = 112.0;
              const bottomLabelWidth = 112.0;
              const labelHeight = 27.0;
              const labelGap = 8.0;
              final width = constraints.maxWidth;
              // Radius is limited by the room left for the side labels.
              final radius =
                  ((width / 2 - sideLabelWidth - labelGap - 2) /
                          math.cos(math.pi / 10))
                      .clamp(36.0, 76.0)
                      .toDouble();
              final centerX = width / 2;
              final centerY = labelHeight + labelGap + radius;
              // A pentagon reaches radius above the centre but only
              // radius * sin(54 deg) below it.
              final bottomVertexY = centerY + radius * math.sin(math.pi * 0.3);
              final totalHeight = bottomVertexY + labelGap + labelHeight;
              final dimensions = recommendation.alignmentDimensions;
              final labels = <Widget>[];

              // Shrinks the font (never below 8) so the widest line of a
              // label fits its box. Long single words no longer break.
              double fittedFontSize(String label, double maxWidth) {
                final painter = TextPainter(
                  textDirection: TextDirection.ltr,
                  textScaler: MediaQuery.textScalerOf(context),
                );
                var widest = 0.0;
                for (final line in label.split('\n')) {
                  painter.text = TextSpan(
                    text: line,
                    style: AppTheme.label(fontSize: 11, color: axisColor),
                  );
                  painter.layout();
                  widest = math.max(widest, painter.width);
                }
                painter.dispose();
                if (widest <= maxWidth || widest == 0) return 11.0;
                return (11.0 * maxWidth / widest).clamp(8.0, 11.0).toDouble();
              }

              for (var index = 0; index < dimensions.length; index++) {
                final label = _formatRadarLabel(dimensions[index].label);
                final pointAngle =
                    -math.pi / 2 + 2 * math.pi * index / dimensions.length;
                final vertexX = centerX + radius * math.cos(pointAngle);
                final vertexY = centerY + radius * math.sin(pointAngle);
                late double left;
                late double top;
                late double labelWidth;
                late TextAlign textAlign;
                late Alignment alignment;

                switch (index) {
                  case 0:
                    labelWidth = math.min(topLabelWidth, width);
                    left = centerX - labelWidth / 2;
                    top = vertexY - labelGap - labelHeight;
                    textAlign = TextAlign.center;
                    alignment = Alignment.bottomCenter;
                    break;
                  case 1:
                    left = vertexX + labelGap;
                    labelWidth = math.min(
                      sideLabelWidth,
                      math.max(0.0, width - left),
                    );
                    top = vertexY - labelHeight / 2;
                    textAlign = TextAlign.left;
                    alignment = Alignment.centerLeft;
                    break;
                  case 2:
                    left = vertexX - 6;
                    labelWidth = math.min(
                      bottomLabelWidth,
                      math.max(0.0, width - left),
                    );
                    top = vertexY + labelGap;
                    textAlign = TextAlign.left;
                    alignment = Alignment.topLeft;
                    break;
                  case 3:
                    final right = vertexX + 6;
                    labelWidth = math.min(
                      bottomLabelWidth,
                      math.max(0.0, right),
                    );
                    left = right - labelWidth;
                    top = vertexY + labelGap;
                    textAlign = TextAlign.right;
                    alignment = Alignment.topRight;
                    break;
                  default:
                    final right = vertexX - labelGap;
                    labelWidth = math.min(sideLabelWidth, math.max(0.0, right));
                    left = right - labelWidth;
                    top = vertexY - labelHeight / 2;
                    textAlign = TextAlign.right;
                    alignment = Alignment.centerRight;
                }

                labels.add(
                  Positioned(
                    key: ValueKey('radar-axis-position-$index'),
                    left: left,
                    top: top,
                    width: labelWidth,
                    height: labelHeight,
                    child: Align(
                      alignment: alignment,
                      child: Text(
                        label,
                        key: ValueKey('radar-axis-label-$index'),
                        maxLines: 2,
                        softWrap: false,
                        textAlign: textAlign,
                        style: AppTheme.label(
                          fontSize: fittedFontSize(label, labelWidth),
                          color: axisColor,
                        ).copyWith(height: 1.05),
                      ),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: totalHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: centerX - radius,
                      top: centerY - radius,
                      width: radius * 2,
                      height: radius * 2,
                      child: RadarChart(
                        key: const ValueKey('radar-chart'),
                        RadarChartData(
                          dataSets: [
                            RadarDataSet(
                              dataEntries: [
                                for (final dimension
                                    in recommendation.alignmentDimensions)
                                  RadarEntry(value: dimension.studentValue),
                              ],
                              fillColor: const Color(0xFFA855F7)
                                  .withValues(alpha: 0.30),
                              borderColor: const Color(0xFFC084FC),
                              borderWidth: 2,
                              entryRadius: 3,
                            ),
                            RadarDataSet(
                              dataEntries: [
                                for (final dimension
                                    in recommendation.alignmentDimensions)
                                  RadarEntry(value: dimension.careerValue),
                              ],
                              fillColor: const Color(0xFF06B6D4)
                                  .withValues(alpha: 0.25),
                              borderColor: const Color(0xFF06B6D4),
                              borderWidth: 2,
                              entryRadius: 3,
                            ),
                            RadarDataSet(
                              dataEntries: [
                                for (
                                  var index = 0;
                                  index <
                                      recommendation.alignmentDimensions.length;
                                  index++
                                )
                                  RadarEntry(value: index.isEven ? 0 : 100),
                              ],
                              fillColor: Colors.transparent,
                              borderColor: Colors.transparent,
                              borderWidth: 0,
                              entryRadius: 0,
                            ),
                          ],
                          radarShape: RadarShape.polygon,
                          radarBackgroundColor: Colors.transparent,
                          radarBorderData: BorderSide(
                            color: gridColor,
                            width: 1,
                          ),
                          gridBorderData: BorderSide(
                            color: gridColor,
                            width: 1,
                          ),
                          tickBorderData: BorderSide(
                            color: angleColor,
                            width: 1,
                          ),
                          tickCount: 4,
                          ticksTextStyle: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 0,
                          ),
                          titleTextStyle: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 0,
                          ),
                          getTitle: (index, angle) =>
                              const RadarChartTitle(text: ''),
                        ),
                      ),
                    ),
                    ...labels,
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            key: const ValueKey('radar-chart-legend'),
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 4,
            children: [
              _RadarLegendItem(
                label: 'Student Vector',
                color: const Color(0xFFC084FC),
                isDark: isDark,
              ),
              _RadarLegendItem(
                label: '${recommendation.title} Spec',
                color: const Color(0xFF06B6D4),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatRadarLabel(String label) {
  final words = label.split(RegExp(r'\s+'));
  if (words.length < 2) return label;

  var splitIndex = 1;
  var smallestDifference = label.length;
  for (var index = 1; index < words.length; index++) {
    final firstLineLength = words.take(index).join(' ').length;
    final secondLineLength = words.skip(index).join(' ').length;
    final difference = (firstLineLength - secondLineLength).abs();
    if (difference < smallestDifference) {
      splitIndex = index;
      smallestDifference = difference;
    }
  }

  return '${words.take(splitIndex).join(' ')}\n'
      '${words.skip(splitIndex).join(' ')}';
}

class _RadarLegendItem extends StatelessWidget {
  const _RadarLegendItem({
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTheme.label(
            fontSize: 9,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _LeadsToChips extends StatelessWidget {
  const _LeadsToChips({required this.careers});

  final List<String> careers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leads to',
          style: AppTheme.label(fontSize: 9, color: AppTheme.muted(context)),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 5,
          runSpacing: 4,
          children: [
            for (final career in careers)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accent(context).withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  career,
                  style: AppTheme.label(
                    fontSize: 9,
                    color: AppTheme.accent(context),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.rank,
    required this.isBachelors,
    required this.onViewSkillGap,
    required this.onExpansionChanged,
  });

  final CareerRecommendation recommendation;
  final int rank;
  final bool isBachelors;
  final VoidCallback onViewSkillGap;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 12,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: AppTheme.primary.withValues(alpha: 0.08),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExpansionTile(
                onExpansionChanged: onExpansionChanged,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 13),
                leading: Container(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryLight.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '#$rank',
                    style: AppTheme.label(
                      fontSize: 10,
                      color: AppTheme.accent(context),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        recommendation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.title(
                          fontSize: 12,
                          color: AppTheme.onCanvas(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MatchBadge(
                      percent: recommendation.matchPercent,
                      color: _rankColor(context, rank),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.reasons.first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: 9,
                          color: AppTheme.muted(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _MatchProgress(
                        percent: recommendation.matchPercent,
                        color: _rankColor(context, rank),
                      ),
                      if (recommendation.leadsTo.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        _LeadsToChips(careers: recommendation.leadsTo),
                      ],
                      if (recommendation.missingSkills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            for (final skill
                                in recommendation.missingSkills.take(2))
                              _SkillGapChip(label: skill),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                children: [
                  _MatchProgress(
                    percent: recommendation.matchPercent,
                    color: _rankColor(context, rank),
                  ),
                  const SizedBox(height: 10),
                  _SectionHeading(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Why It Fits',
                  ),
                  const SizedBox(height: 7),
                  for (final reason in recommendation.reasons)
                    _BulletLine(
                      icon: Icons.check_rounded,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.cyan
                          : const Color(0xFF0E7490),
                      text: reason,
                    ),
                  if (recommendation.leadsTo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SectionHeading(
                      icon: Icons.work_outline_rounded,
                      title: 'Leads to',
                    ),
                    const SizedBox(height: 7),
                    _LeadsToChips(careers: recommendation.leadsTo),
                  ],
                  const SizedBox(height: 10),
                  _SectionHeading(
                    icon: Icons.track_changes_rounded,
                    title: 'Skill Gaps',
                  ),
                  const SizedBox(height: 7),
                  if (recommendation.skillGaps.isEmpty)
                    Text(
                      'No skills are listed for this career in the local dataset.',
                      style: AppTheme.body(
                        fontSize: 10,
                        color: AppTheme.muted(context),
                      ),
                    )
                  else if (recommendation.missingSkills.isEmpty)
                    Text(
                      'No major gaps identified in the dataset-listed skills.',
                      style: AppTheme.body(
                        fontSize: 10,
                        color: AppTheme.muted(context),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final skill in recommendation.missingSkills)
                          _SkillGapChip(label: skill),
                      ],
                    ),
                  const SizedBox(height: 12),
                  _SectionHeading(
                    icon: Icons.school_rounded,
                    title: 'Learning Resources',
                  ),
                  const SizedBox(height: 6),
                  for (final resource in recommendation.learningResources)
                    _ResourceLine(resource: resource),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('view-skill-gap-${recommendation.title}'),
                    onPressed: onViewSkillGap,
                    icon: const Icon(Icons.track_changes_rounded, size: 13),
                    label: Text(
                      recommendation.leadsTo.isEmpty
                          ? 'View Skill Gap'
                          : isBachelors
                          ? 'View Skill Plan'
                          : 'View Study Plan',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AppTheme.label(
                        fontSize: 9,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _rankColor(BuildContext context, int rank) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (!isDark) {
    return switch (rank) {
      1 => const Color(0xFF0E7490),
      2 => const Color(0xFF6B21A8),
      3 => const Color(0xFFBE185D),
      4 => const Color(0xFFB45309),
      _ => AppTheme.lightPrimary,
    };
  }
  return switch (rank) {
    1 => AppTheme.cyan,
    2 => AppTheme.primaryLight,
    3 => const Color(0xFFEC4899),
    4 => AppTheme.amber,
    _ => AppTheme.accent(context),
  };
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$percent%',
        style: AppTheme.label(fontSize: 10, color: color),
      ),
    );
  }
}

class _MatchProgress extends StatelessWidget {
  const _MatchProgress({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: percent / 100,
        minHeight: 5,
        backgroundColor: AppTheme.muted(context).withValues(alpha: 0.16),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.accent(context)),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTheme.label(
            fontSize: 11,
            color: AppTheme.onCanvas(context),
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: AppTheme.body(
                fontSize: 11,
                color: AppTheme.muted(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillGapChip extends StatelessWidget {
  const _SkillGapChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.amber
        : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: AppTheme.label(fontSize: 9, color: color)),
    );
  }
}

class _ResourceLine extends StatelessWidget {
  const _ResourceLine({required this.resource});

  final LearningResource resource;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resourceAccent = isDark ? AppTheme.cyan : const Color(0xFF0E7490);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final opened = await launchUrl(
              Uri.parse(resource.url),
              mode: LaunchMode.externalApplication,
            );
            if (!opened && context.mounted) {
              showAppSnackBar(context, 'Could not open this resource.');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: resourceAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: resourceAccent,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title,
                        style: AppTheme.label(
                          fontSize: 10,
                          color: AppTheme.onCanvas(context),
                        ),
                      ),
                      Text(
                        resource.provider,
                        style: AppTheme.body(
                          fontSize: 9,
                          color: AppTheme.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: AppTheme.muted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({required this.onViewHistory, required this.onRetake});

  final VoidCallback onViewHistory;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onViewHistory,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.surface
                  : AppTheme.lightSurface,
              foregroundColor: AppTheme.onCanvas(context),
              side: BorderSide(
                color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'View History',
              style: AppTheme.label(
                fontSize: 10,
                color: AppTheme.onCanvas(context),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextButton(
              onPressed: onRetake,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retake Quiz',
                style: AppTheme.label(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.rose, size: 36),
            const SizedBox(height: 12),
            Text(
              'Could not load career results',
              style: AppTheme.title(
                fontSize: 16,
                color: AppTheme.onCanvas(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTheme.body(
                fontSize: 11,
                color: AppTheme.muted(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
