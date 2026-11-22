import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import 'history_screen.dart';
import '../services/history_repository.dart';
import '../widgets/glass_card.dart';
import '../widgets/theme_mode_button.dart';

class SavedMatchesScreen extends StatelessWidget {
  const SavedMatchesScreen({
    super.key,
    required this.record,
    this.showBackButton = false,
  });

  final AssessmentRecord record;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('saved-career-matches-list'),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      children: [
        _SavedMatchesHeader(
          title: record.educationLevel.trim().toLowerCase() == 'matric'
              ? 'Recommended Study Paths'
              : 'Top Career Matches',
          subtitle:
              'Saved assessment · ${formatAssessmentDateTime(record.createdAt)}',
          showBackButton: showBackButton,
        ),
        const SizedBox(height: 13),
        GlassCard(
          isSelected: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.topCareer,
                style: AppTheme.heading(
                  fontSize: 18,
                  color: AppTheme.onCanvas(context),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${record.educationLevel} · ${record.group}',
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppTheme.muted(context),
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < record.top5.length; index++) ...[
                _SavedCareerMatchRow(
                  rank: index + 1,
                  match: record.top5[index],
                ),
                if (index < record.top5.length - 1) const SizedBox(height: 9),
              ],
              if (record.top5.isEmpty)
                Text(
                  record.educationLevel.trim().toLowerCase() == 'matric'
                      ? 'No study paths were stored for this assessment.'
                      : 'No career matches were stored for this assessment.',
                  style: AppTheme.body(
                    fontSize: 12,
                    color: AppTheme.muted(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedMatchesHeader extends StatelessWidget {
  const _SavedMatchesHeader({
    required this.title,
    required this.subtitle,
    required this.showBackButton,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;

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
        if (showBackButton)
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
        const ThemeModeButton(),
      ],
    );
  }
}

class _SavedCareerMatchRow extends StatelessWidget {
  const _SavedCareerMatchRow({required this.rank, required this.match});

  final int rank;
  final AssessmentCareerMatch match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppTheme.cyan : const Color(0xFF0369A1);
    return Row(
      children: [
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.accent(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rank',
            style: AppTheme.label(
              fontSize: 10,
              color: AppTheme.accent(context),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            match.title,
            style: AppTheme.label(
              fontSize: 11,
              color: AppTheme.onCanvas(context),
            ),
          ),
        ),
        Text(
          '${match.matchPercent}%',
          style: AppTheme.label(fontSize: 11, color: color),
        ),
      ],
    );
  }
}