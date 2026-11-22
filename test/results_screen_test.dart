import 'dart:math' as math;

import 'package:ai_career_advisor/constants/app_theme.dart';
import 'package:ai_career_advisor/models/student_profile.dart';
import 'package:ai_career_advisor/screens/results_screen.dart';
import 'package:ai_career_advisor/services/recommendation_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_unified_model_runner.dart';

const _testRecommendationService = RecommendationService(
  unifiedModelRunner: FakeUnifiedModelRunner(),
);

class _FixedRecommendationService extends RecommendationService {
  _FixedRecommendationService(this.recommendations);

  final List<CareerRecommendation> recommendations;

  @override
  Future<List<CareerRecommendation>> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) async => recommendations;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('radar card fits long axis labels at a narrow width', (
    tester,
  ) async {
    const labelSets = [
      [
        'Object-Oriented Programming',
        'Financial Statement Analysis',
        'Civics & Political Science',
        'Mobile App Development',
        'Mathematics',
      ],
      [
        'Conventional',
        'Object-Oriented Programming',
        'Financial Statement Analysis',
        'Civics & Political Science',
        'Mobile App Development',
      ],
    ];

    for (final width in [360.0, 411.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        for (final labels in labelSets) {
          final recommendation = CareerRecommendation(
            title: 'Software Engineer',
            matchPercent: 90,
            engineName: 'test',
            alignmentDimensions: [
              for (var index = 0; index < labels.length; index++)
                CareerAlignmentDimension(
                  label: labels[index],
                  studentValue: 80 - index * 5,
                  careerValue: 90 - index * 5,
                ),
            ],
            typicalAcademicScore: 0,
            skillGaps: const [],
            reasons: const [],
            missingSkills: const [],
            learningResources: const [],
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: RadarAlignmentCard(recommendation: recommendation),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final chart = tester.widget<RadarChart>(find.byType(RadarChart));
          expect([
            for (var index = 0; index < labels.length; index++)
              chart.data.getTitle!(index, 0).text,
          ], everyElement(isEmpty));
          expect(
            [
              for (var index = 0; index < labels.length; index++)
                tester.widget<Text>(
                  find.byKey(ValueKey('radar-axis-label-$index')),
                ),
            ].every((label) => label.data!.split('\n').length <= 2),
            isTrue,
          );
          final labelRects = [
            for (var index = 0; index < labels.length; index++)
              tester.getRect(find.byKey(ValueKey('radar-axis-label-$index'))),
          ];
          for (var first = 0; first < labelRects.length; first++) {
            for (var second = first + 1; second < labelRects.length; second++) {
              expect(
                labelRects[first].overlaps(labelRects[second]),
                isFalse,
                reason: 'Axis labels $first and $second overlap at $width px',
              );
            }
          }

          final subtitleRect = tester.getRect(
            find.byKey(const ValueKey('radar-chart-subtitle')),
          );
          final legendRect = tester.getRect(
            find.byKey(const ValueKey('radar-chart-legend')),
          );
          final chartRect = tester.getRect(
            find.byKey(const ValueKey('radar-chart')),
          );
          final center = chartRect.center;
          final radius = math.min(chartRect.width, chartRect.height) / 2;
          for (final rect in labelRects) {
            expect(rect.overlaps(subtitleRect), isFalse);
            expect(rect.overlaps(legendRect), isFalse);
            final nearestX = center.dx.clamp(rect.left, rect.right);
            final nearestY = center.dy.clamp(rect.top, rect.bottom);
            final distance = math.sqrt(
              math.pow(center.dx - nearestX, 2) +
                  math.pow(center.dy - nearestY, 2),
            );
            expect(distance, greaterThanOrEqualTo(radius));
          }
          expect(
            labelRects.first.top - subtitleRect.bottom,
            greaterThanOrEqualTo(12),
          );
          expect(
            legendRect.top -
                math.max(labelRects[2].bottom, labelRects[3].bottom),
            greaterThanOrEqualTo(12),
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('radar-alignment-card')))
                .height,
            inInclusiveRange(300, 330),
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('radar compares profile vectors to the selected career', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const academicProfile = StudentAcademicProfile(
      educationLevel: 'Bachelors',
      specialization: 'BS Software Engineering / Computer Science',
      academicScore: 3.2,
      scoreType: AcademicScoreType.cgpa,
    );
    const riasecScores = {'R': 3, 'I': 5, 'A': 3, 'S': 2, 'E': 3, 'C': 4};
    const skillRatings = {
      'Programming Fundamentals': 4,
      'Data Structures & Algorithms': 4,
      'Database Management': 3,
    };
    late final List<CareerRecommendation> recommendations;
    await tester.runAsync(() async {
      recommendations = await _testRecommendationService.recommend(
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ResultsScreen(
          academicProfile: academicProfile,
          riasecScores: riasecScores,
          skillRatings: skillRatings,
          recommendationService: _testRecommendationService,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('${recommendations.first.title} Spec'), findsOneWidget);
    // The hero button always exists; list cards below may also be built.
    expect(find.text('View Skill Plan'), findsWidgets);
    expect(find.text('View Study Plan'), findsNothing);
    expect(find.text('Career matched to your interests'), findsOneWidget);
    expect(
      find.text('Student Vector vs ${recommendations.first.title} Benchmark'),
      findsOneWidget,
    );
    var chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(chart.data.dataSets, hasLength(3));
    expect(chart.data.dataSets.take(2), hasLength(2));
    expect(chart.data.tickCount, 4);
    expect(chart.data.minEntry.value, 0);
    expect(chart.data.maxEntry.value, 100);
    for (final dataSet in chart.data.dataSets.take(2)) {
      expect(dataSet.dataEntries, hasLength(5));
      for (final entry in dataSet.dataEntries) {
        expect(entry.value, inInclusiveRange(0, 100));
      }
    }
    expect(chart.data.dataSets.last.fillColor, Colors.transparent);
    expect(chart.data.dataSets.last.borderColor, Colors.transparent);
    expect(chart.data.dataSets.last.entryRadius, 0);
    expect(tester.takeException(), isNull);

    final secondCareer = recommendations[1];
    final matchesScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(secondCareer.title),
      100,
      scrollable: matchesScrollable,
    );
    await tester.ensureVisible(find.text(secondCareer.title));
    await tester.pump();
    await tester.tap(find.text(secondCareer.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Vector Alignment Analysis'),
      -250,
      scrollable: matchesScrollable,
    );
    await tester.ensureVisible(find.text('Vector Alignment Analysis'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('${secondCareer.title} Spec'), findsOneWidget);
    chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(
      chart.data.dataSets.first.dataEntries
          .map((entry) => entry.value)
          .toList(),
      secondCareer.alignmentDimensions
          .map((dimension) => dimension.studentValue)
          .toList(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard tabs show matches, roadmap, and saved history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ResultsScreen(
          academicProfile: const StudentAcademicProfile(
            educationLevel: 'Bachelors',
            specialization: 'BS Software Engineering / Computer Science',
            academicScore: 3.2,
            scoreType: AcademicScoreType.cgpa,
          ),
          riasecScores: const {'R': 3, 'I': 5, 'A': 3, 'S': 2, 'E': 3, 'C': 4},
          skillRatings: const {
            'Programming Fundamentals': 4,
            'Data Structures & Algorithms': 4,
            'Database Management': 3,
          },
          recommendationService: _testRecommendationService,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.text('Your Career Matches'), findsOneWidget);
    final matchesScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Other Recommended Matches'),
      250,
      scrollable: matchesScrollable,
    );
    await tester.ensureVisible(find.text('Other Recommended Matches'));
    await tester.pump();
    expect(find.text('Other Recommended Matches'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Your Career Matches'),
      -250,
      scrollable: matchesScrollable,
    );
    await tester.ensureVisible(find.text('Your Career Matches'));
    await tester.pump();

    await tester.tap(find.text('Roadmap').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Career Roadmap'), findsOneWidget);

    await tester.tap(find.text('History').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('1 saved assessment'), findsOneWidget);

    await tester.tap(find.text('Matches').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Save to History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('History').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('No assessments yet'), findsNothing);
    expect(find.text('View Matches'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hybrid results show the on-device model subtitle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = RecommendationService(
      unifiedModelRunner: FakeUnifiedModelRunner(
        probabilities: List<double>.filled(79, 1),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ResultsScreen(
          academicProfile: const StudentAcademicProfile(
            educationLevel: 'Bachelors',
            specialization: 'BS Software Engineering / Computer Science',
            academicScore: 3.2,
            scoreType: AcademicScoreType.cgpa,
          ),
          riasecScores: const {'R': 3, 'I': 5, 'A': 3, 'S': 2, 'E': 3, 'C': 4},
          skillRatings: const {'Programming Fundamentals': 4},
          recommendationService: service,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.text(RecommendationService.tfliteSubtitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected career roadmap shows gaps and saves that plan', (
    tester,
  ) async {
    void expectNoException(String phase) {
      final exception = tester.takeException();
      expect(exception, isNull, reason: '$phase: $exception');
    }

    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const academicProfile = StudentAcademicProfile(
      educationLevel: 'Bachelors',
      specialization: 'BS Software Engineering / Computer Science',
      academicScore: 3.2,
      scoreType: AcademicScoreType.cgpa,
    );
    const riasecScores = {'R': 3, 'I': 5, 'A': 3, 'S': 2, 'E': 3, 'C': 4};
    const skillRatings = {
      'Programming Fundamentals': 4,
      'Data Structures & Algorithms': 4,
      'Database Management': 3,
    };
    late final List<CareerRecommendation> recommendations;
    await tester.runAsync(() async {
      recommendations = await _testRecommendationService.recommend(
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ResultsScreen(
          academicProfile: academicProfile,
          riasecScores: riasecScores,
          skillRatings: skillRatings,
          recommendationService: _testRecommendationService,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expectNoException('Initial render');

    final selectedCareer = recommendations[1];
    final selectedCareerButton = find.byKey(
      ValueKey('view-skill-gap-${selectedCareer.title}'),
    );
    final matchesScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      selectedCareerButton,
      120,
      scrollable: matchesScrollable,
    );
    await tester.ensureVisible(selectedCareerButton);
    await tester.pump();
    await tester.tap(selectedCareerButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expectNoException('Opening selected career');

    expect(
      find.text('Skill-gap plan for ${selectedCareer.title}'),
      findsOneWidget,
    );
    expect(find.text('SELECTED CAREER'), findsOneWidget);
    expect(find.text('#1 TOP RECOMMENDATION'), findsNothing);
    final roadmapScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Why This Fits Your Profile'),
      100,
      scrollable: roadmapScrollable,
    );
    await tester.ensureVisible(find.text('Why This Fits Your Profile'));
    await tester.pump();
    expectNoException('Why-fit section');
    expect(find.text('Why This Fits Your Profile'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Skill Gap Analysis'),
      120,
      scrollable: roadmapScrollable,
    );
    await tester.ensureVisible(find.text('Skill Gap Analysis'));
    await tester.pump();
    expectNoException('Gap-analysis section');
    final gapCount = selectedCareer.skillGaps
        .where((skill) => skill.difference > 0)
        .length;
    expect(find.text('$gapCount Gaps to Build'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Free Learning Resources'),
      120,
      scrollable: roadmapScrollable,
    );
    await tester.ensureVisible(find.text('Free Learning Resources'));
    await tester.pump();
    expectNoException('Learning resources section');
    expect(find.text('Free Learning Resources'), findsOneWidget);

    for (final skill in selectedCareer.skillGaps) {
      final statusFinder = find.byKey(
        ValueKey('skill-gap-status-${skill.skillName}'),
      );
      await tester.scrollUntilVisible(
        statusFinder,
        100,
        scrollable: roadmapScrollable,
      );
      await tester.ensureVisible(statusFinder);
      await tester.pump();
      expectNoException('${skill.skillName} status');
      final badge = tester.widget<Container>(statusFinder);
      final decoration = badge.decoration! as BoxDecoration;
      final expectedColor = switch (skill.status) {
        SkillGapStatus.needsAttention => const Color(0xFFDC2626),
        SkillGapStatus.developing => const Color(0xFFB45309),
        SkillGapStatus.matchedStrength => const Color(0xFF047857),
      };
      expect(
        (decoration.border! as Border).top.color,
        expectedColor.withValues(alpha: 0.3),
      );
    }

    await tester.tap(find.byKey(const ValueKey('save-learning-plan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expectNoException('Saving plan');
    final preferences = await SharedPreferences.getInstance();
    final savedPlan = preferences.getString('saved_career_learning_plan');
    expect(savedPlan, contains(selectedCareer.title));
    expect(
      find.text('${selectedCareer.title} saved to your learning plan.'),
      findsOneWidget,
    );
    expectNoException('Final render');
  });

  testWidgets('Matric history opens saved study-path matches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ResultsScreen(
          academicProfile: const StudentAcademicProfile(
            educationLevel: 'Matric',
            specialization: 'Science Group (Bio-Science)',
            academicScore: 88,
            scoreType: AcademicScoreType.percentage,
          ),
          riasecScores: const {'R': 2, 'I': 5, 'A': 2, 'S': 4, 'E': 2, 'C': 3},
          skillRatings: const {
            'English': 3,
            'Mathematics': 3,
            'Physics': 4,
            'Chemistry': 5,
            'Biology': 5,
          },
          recommendationService: _testRecommendationService,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.text('Recommended Study Paths'), findsOneWidget);
    expect(find.text('View Study Plan'), findsWidgets);

    await tester.tap(find.text('History').last);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('Pre-Medical'), findsWidgets);
    await tester.tap(find.text('View Matches'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Recommended Study Paths'), findsOneWidget);
    expect(find.text('Pre-Medical'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Intermediate results retain study-plan wording', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ResultsScreen(
          academicProfile: const StudentAcademicProfile(
            educationLevel: 'Intermediate',
            specialization: 'Pre-Engineering (Math, Physics, Chemistry)',
            academicScore: 88,
            scoreType: AcademicScoreType.percentage,
          ),
          riasecScores: const {'R': 2, 'I': 5, 'A': 2, 'S': 4, 'E': 2, 'C': 3},
          skillRatings: const {'Mathematics': 4, 'Physics': 4, 'Chemistry': 3},
          recommendationService: _FixedRecommendationService([
            CareerRecommendation(
              title: 'Software Engineer',
              leadsTo: const ['Mobile App Developer'],
              matchPercent: 90,
              engineName: 'test',
              alignmentDimensions: const [
                CareerAlignmentDimension(
                  label: 'Conventional',
                  studentValue: 80,
                  careerValue: 90,
                ),
                CareerAlignmentDimension(
                  label: 'Object-Oriented Programming',
                  studentValue: 75,
                  careerValue: 85,
                ),
                CareerAlignmentDimension(
                  label: 'Financial Statement Analysis',
                  studentValue: 70,
                  careerValue: 80,
                ),
                CareerAlignmentDimension(
                  label: 'Mobile App Development',
                  studentValue: 65,
                  careerValue: 75,
                ),
                CareerAlignmentDimension(
                  label: 'Mathematics',
                  studentValue: 60,
                  careerValue: 70,
                ),
              ],
              typicalAcademicScore: 0,
              skillGaps: const [],
              reasons: const ['A good fit for this profile.'],
              missingSkills: const [],
              learningResources: const [],
            ),
          ]),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.text('View Study Plan'), findsOneWidget);
    expect(find.text('Study path matched to your interests'), findsOneWidget);
    expect(find.text('View Skill Plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
