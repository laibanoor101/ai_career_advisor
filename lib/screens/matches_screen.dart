import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/student_profile.dart';
import '../widgets/glass_card.dart';
import '../widgets/theme_mode_button.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({
    super.key,
    required this.academicProfile,
    required this.riasecScores,
    required this.skillRatings,
  });

  final StudentAcademicProfile academicProfile;
  final Map<String, int> riasecScores;
  final Map<String, int> skillRatings;

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.onCanvas(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          academicProfile.educationLevel.trim().toLowerCase() == 'matric'
              ? 'Recommended Study Paths'
              : 'Top Career Matches',
          style: AppTheme.heading(fontSize: 20, color: textColor),
        ),
        actions: const [ThemeModeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GlassCard(
            isSelected: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accent(context),
                    size: 25,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your profile is ready',
                  style: AppTheme.heading(fontSize: 22, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your academic background, career interests, and skill ratings have been collected for matching.',
                  style: AppTheme.body(
                    fontSize: 14,
                    color: AppTheme.muted(context),
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileSummaryRow(
                  icon: Icons.school_rounded,
                  label: 'Education',
                  value:
                      '${academicProfile.educationLevel} · '
                      '${academicProfile.specialization}',
                ),
                const SizedBox(height: 12),
                _ProfileSummaryRow(
                  icon: Icons.psychology_rounded,
                  label: 'Interest profile',
                  value: '${riasecScores.length} RIASEC scores recorded',
                ),
                const SizedBox(height: 12),
                _ProfileSummaryRow(
                  icon: Icons.stars_rounded,
                  label: 'Core skills',
                  value: '${skillRatings.length} skills rated',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryRow extends StatelessWidget {
  const _ProfileSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.accent(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.label(
                  fontSize: 11,
                  color: AppTheme.muted(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.body(
                  fontSize: 12,
                  color: AppTheme.onCanvas(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
