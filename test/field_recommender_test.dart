import 'dart:convert';

import 'package:ai_career_advisor/constants/app_theme.dart';
import 'package:ai_career_advisor/models/student_profile.dart';
import 'package:ai_career_advisor/screens/academic_profile_screen.dart';
import 'package:ai_career_advisor/screens/skills_screen.dart';
import 'package:ai_career_advisor/services/recommendation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_unified_model_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Intermediate skill catalog mirrors JSON for all five groups', () async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/data/intermediate_knowledge.json'),
    ) as Map<String, dynamic>;
    final groups = decoded['groups'] as List<dynamic>;

    expect(groups, hasLength(5));
    expect(
      groups.map((group) => (group as Map<String, dynamic>)['group']),
      academicSpecializationOptions['Intermediate'],
    );
    for (final rawGroup in groups) {
      final group = rawGroup as Map<String, dynamic>;
      final name = group['group'] as String;
      final jsonSkills = (group['skills'] as List<dynamic>)
          .map(
            (skill) => (
              name: (skill as Map<String, dynamic>)['name'] as String,
              category: skill['category'] as String,
            ),
          )
          .toList();
      expect(SkillsScreen.intermediateSkillsForGroup(name), jsonSkills);
      expect(
        SkillsScreen.skillNamesForEducationLevel(
          'Intermediate',
          specialization: name,
        ),
        jsonSkills.map((skill) => skill.name),
      );
    }
  });

  test('Bachelors skill catalog mirrors JSON for all five majors', () async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/data/bachelors_knowledge.json'),
    ) as Map<String, dynamic>;
    final groups = decoded['groups'] as List<dynamic>;

    expect(groups, hasLength(5));
    expect(
      groups.map((group) => (group as Map<String, dynamic>)['group']),
      academicSpecializationOptions['Bachelors'],
    );
    for (final rawGroup in groups) {
      final group = rawGroup as Map<String, dynamic>;
      final name = group['group'] as String;
      final jsonSkills = (group['skills'] as List<dynamic>)
          .map(
            (skill) => (
              name: (skill as Map<String, dynamic>)['name'] as String,
              category: skill['category'] as String,
              hint: skill['hint'] as String? ?? '',
            ),
          )
          .toList();
      expect(jsonSkills, hasLength(14));
      expect(SkillsScreen.bachelorsSkillsForGroup(name), jsonSkills);
      expect(
        SkillsScreen.skillNamesForEducationLevel(
          'Bachelors',
          specialization: name,
        ),
        jsonSkills.map((skill) => skill.name),
      );
    }
  });

  testWidgets('Bachelors shows only major skills with default rating 3', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groups = bachelorsSkillsByGroup.keys.toList(growable: false);
    final allSkills = bachelorsSkillsByGroup.values
        .expand((skills) => skills.map((skill) => skill.name))
        .toSet();

    for (final group in groups) {
      final expectedSkills = bachelorsSkillsByGroup[group]!
          .map((skill) => skill.name)
          .toSet();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsScreen(
            key: ValueKey(group),
            academicProfile: StudentAcademicProfile(
              educationLevel: 'Bachelors',
              specialization: group,
              academicScore: 3.2,
              scoreType: AcademicScoreType.cgpa,
            ),
            riasecScores: const {
              'R': 3,
              'I': 3,
              'A': 3,
              'S': 3,
              'E': 3,
              'C': 3,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('14 of 14 rated'), findsOneWidget, reason: group);
      expect(
        tester
            .widgetList<Slider>(find.byType(Slider))
            .every((slider) => slider.value == 3),
        isTrue,
      );
      for (final skill in expectedSkills) {
        expect(find.text(skill), findsOneWidget, reason: group);
      }
      for (final skill in allSkills.difference(expectedSkills)) {
        expect(find.text(skill), findsNothing, reason: '$group shows $skill');
      }
      for (final skill in bachelorsSkillsByGroup[group]!) {
        if (skill.hint.isNotEmpty) {
          expect(find.text(skill.hint), findsOneWidget, reason: skill.name);
        }
      }
    }
  });

  testWidgets('Bachelors skill hints fit in both themes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: SkillsScreen(
            academicProfile: const StudentAcademicProfile(
              educationLevel: 'Bachelors',
              specialization: 'BS Software Engineering / Computer Science',
              academicScore: 3.2,
              scoreType: AcademicScoreType.cgpa,
            ),
            riasecScores: const {
              'R': 3,
              'I': 3,
              'A': 3,
              'S': 3,
              'E': 3,
              'C': 3,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hint = tester.widget<Text>(find.text('Python, C++ or Java'));
      expect(hint.maxLines, 1);
      expect(hint.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    }
  });

  test('Bachelors recommendations stay inside the selected major', () async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/data/bachelors_knowledge.json'),
    ) as Map<String, dynamic>;
    for (final rawGroup in decoded['groups'] as List<dynamic>) {
      final group = rawGroup as Map<String, dynamic>;
      final name = group['group'] as String;
      final fields = (group['fields'] as List<dynamic>)
          .map((field) => (field as Map<String, dynamic>)['title'] as String)
          .toSet();
      final recommendations = await _recommend(
        specialization: name,
        educationLevel: 'Bachelors',
        riasec: const {'R': 3, 'I': 3, 'A': 3, 'S': 3, 'E': 3, 'C': 3},
        skills: {
          for (final skill in SkillsScreen.skillNamesForEducationLevel(
            'Bachelors',
            specialization: name,
          ))
            skill: 3,
        },
      );

      expect(recommendations, hasLength(5));
      expect(
        recommendations.map((recommendation) => recommendation.title).toSet(),
        everyElement(isIn(fields)),
      );
      expect(
        recommendations.every(
          (recommendation) =>
              recommendation.engineName ==
              RecommendationService.streamRulesEngineName,
        ),
        isTrue,
      );
      expect(
        recommendations.every(
          (recommendation) => recommendation.typicalAcademicScore == 0,
        ),
        isTrue,
      );
    }
  });

  test(
    'Bachelors RIASEC and skill profiles rank their expected careers',
    () async {
      const scenarios =
          <
            ({
              String group,
              Map<String, int> riasec,
              Map<String, int> strengths,
              String expected,
            })
          >[
            (
              group: 'BS Software Engineering / Computer Science',
              riasec: {'R': 1, 'I': 3, 'A': 5, 'S': 4, 'E': 2, 'C': 2},
              strengths: {
                'UI/UX Design & Prototyping': 5,
                'Web Development Basics': 4,
                'SDLC & Agile/Scrum': 4,
              },
              expected: 'UI/UX Designer',
            ),
            (
              group: 'BS Software Engineering / Computer Science',
              riasec: {'R': 2, 'I': 5, 'A': 1, 'S': 2, 'E': 2, 'C': 4},
              strengths: {
                'Database Management': 5,
                'RESTful APIs & Backend Integration': 5,
                'Data Structures & Algorithms': 5,
                'Programming Fundamentals': 4,
              },
              expected: 'Backend / Database Engineer',
            ),
            (
              group: 'BS Software Engineering / Computer Science',
              riasec: {'R': 3, 'I': 5, 'A': 1, 'S': 2, 'E': 2, 'C': 4},
              strengths: {
                'Cloud Computing Basics': 5,
                'Operating Systems & Linux': 5,
                'Version Control': 5,
              },
              expected: 'Cloud & DevOps Engineer',
            ),
            (
              group: 'BE Electrical / Electronics Engineering',
              riasec: {'R': 4, 'I': 4, 'A': 2, 'S': 1, 'E': 1, 'C': 4},
              strengths: {
                'PCB Design & Layout': 5,
                'Circuit Design & Analysis': 5,
                'Lab Equipment Handling': 5,
                'Troubleshooting & Fault Diagnosis': 5,
              },
              expected: 'PCB & Hardware Design Engineer',
            ),
            (
              group: 'BE Electrical / Electronics Engineering',
              riasec: {'R': 4, 'I': 4, 'A': 1, 'S': 2, 'E': 2, 'C': 4},
              strengths: {
                'Power Systems & Electrical Machines': 5,
                'Circuit Design & Analysis': 4,
                'Microcontrollers & Embedded Systems': 3,
              },
              expected: 'Power Systems Engineer',
            ),
            (
              group: 'BE Electrical / Electronics Engineering',
              riasec: {'R': 5, 'I': 3, 'A': 1, 'S': 2, 'E': 2, 'C': 4},
              strengths: {
                'Control Systems & Automation': 5,
                'AutoCAD Electrical': 4,
                'Troubleshooting & Fault Diagnosis': 5,
              },
              expected: 'Industrial Automation & PLC Engineer',
            ),
            (
              group: 'BBA / BS Accounting & Finance',
              riasec: {'R': 1, 'I': 4, 'A': 1, 'S': 2, 'E': 2, 'C': 5},
              strengths: {
                'Auditing & Internal Controls': 5,
                'Financial Statement Analysis': 4,
              },
              expected: 'Internal / External Auditor',
            ),
            (
              group: 'BBA / BS Accounting & Finance',
              riasec: {'R': 1, 'I': 3, 'A': 5, 'S': 4, 'E': 5, 'C': 2},
              strengths: {
                'Digital Marketing & Market Research': 5,
                'Negotiation & Client Relationship Management': 5,
                'Presentation & Pitching Skills': 5,
              },
              expected: 'Digital Marketing & Brand Strategist',
            ),
            (
              group: 'BS Biotechnology / Microbiology',
              riasec: {'R': 1, 'I': 5, 'A': 2, 'S': 1, 'E': 1, 'C': 4},
              strengths: {
                'Bioinformatics & Sequence Analysis': 5,
                'Scientific Research & Literature Review': 5,
                'Statistical Data Analysis': 5,
              },
              expected: 'Bioinformatics Analyst',
            ),
            (
              group: 'BS Biotechnology / Microbiology',
              riasec: {'R': 4, 'I': 5, 'A': 1, 'S': 1, 'E': 1, 'C': 5},
              strengths: {
                'Aseptic Techniques & Sterilization': 5,
                'Microbial Culturing & Isolation': 5,
                'Microscopy & Staining Techniques': 5,
                'Quality Control & Quality Assurance': 4,
              },
              expected: 'Quality Control (QC) Microbiologist',
            ),
            (
              group: 'BS Psychology / Social Sciences',
              riasec: {'R': 1, 'I': 4, 'A': 2, 'S': 5, 'E': 2, 'C': 3},
              strengths: {
                'Active Listening & Empathy': 5,
                'Counseling & Interviewing Techniques': 5,
                'Case History Taking & Clinical Observation': 5,
              },
              expected: 'Clinical / Counseling Psychologist',
            ),
          ];

      for (final scenario in scenarios) {
        final skills = {
          for (final skill in SkillsScreen.skillNamesForEducationLevel(
            'Bachelors',
            specialization: scenario.group,
          ))
            skill: scenario.strengths[skill] ?? 1,
        };
        final recommendations = await _recommend(
          educationLevel: 'Bachelors',
          specialization: scenario.group,
          riasec: scenario.riasec,
          skills: skills,
        );
        expect(
          recommendations.first.title,
          scenario.expected,
          reason: scenario.group,
        );
      }
    },
  );

  testWidgets('Intermediate shows only selected group skills with default 3', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groupNames = academicSpecializationOptions['Intermediate']!;
    final allSkills = intermediateSkillsByGroup.values
        .expand((skills) => skills.map((skill) => skill.name))
        .toSet();

    for (final group in groupNames) {
      final expectedSkills = intermediateSkillsByGroup[group]!
          .map((skill) => skill.name)
          .toSet();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsScreen(
            key: ValueKey(group),
            academicProfile: StudentAcademicProfile(
              educationLevel: 'Intermediate',
              specialization: group,
              academicScore: 84,
              scoreType: AcademicScoreType.percentage,
            ),
            riasecScores: const {
              'R': 3,
              'I': 3,
              'A': 3,
              'S': 3,
              'E': 3,
              'C': 3,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final skill in expectedSkills) {
        expect(find.text(skill), findsOneWidget, reason: group);
      }
      for (final skill in allSkills.difference(expectedSkills)) {
        expect(find.text(skill), findsNothing, reason: '$group shows $skill');
      }
      expect(find.text('Urdu'), findsNothing);
      expect(find.text('Islamiat'), findsNothing);
      expect(find.text('Pakistan Studies'), findsNothing);
      expect(
        tester
            .widgetList<Slider>(find.byType(Slider))
            .every((slider) => slider.value == 3),
        isTrue,
      );
      expect(find.text('Progress: '), findsOneWidget);
      expect(
        find.text('${expectedSkills.length} of ${expectedSkills.length} rated'),
        findsOneWidget,
      );
    }
  });

  test('Intermediate results stay inside the selected group', () async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/data/intermediate_knowledge.json'),
    ) as Map<String, dynamic>;
    final groups = decoded['groups'] as List<dynamic>;
    for (final rawGroup in groups) {
      final group = rawGroup as Map<String, dynamic>;
      final name = group['group'] as String;
      final fields = (group['fields'] as List<dynamic>)
          .map((field) => (field as Map<String, dynamic>)['title'] as String)
          .toSet();
      final recommendations = await _recommend(
        specialization: name,
        riasec: const {'R': 3, 'I': 3, 'A': 3, 'S': 3, 'E': 3, 'C': 3},
        skills: {
          for (final skill in SkillsScreen.skillNamesForEducationLevel(
            'Intermediate',
            specialization: name,
          ))
            skill: 3,
        },
      );

      expect(recommendations, hasLength(fields.length < 5 ? fields.length : 5));
      expect(
        recommendations.map((recommendation) => recommendation.title).toSet(),
        everyElement(isIn(fields)),
      );
      expect(
        recommendations.every(
          (recommendation) =>
              recommendation.engineName ==
              RecommendationService.streamRulesEngineName,
        ),
        isTrue,
      );
      expect(
        recommendations.every(
          (recommendation) => recommendation.typicalAcademicScore == 0,
        ),
        isTrue,
      );
    }
  });

  test(
    'Intermediate skill and RIASEC profiles rank their expected fields',
    () async {
      const scenarios =
          <
            ({
              String group,
              Map<String, int> riasec,
              Map<String, int> strengths,
              String expected,
            })
          >[
            (
              group: 'Pre-Engineering (Math, Physics, Chemistry)',
              riasec: {'R': 4, 'I': 5, 'A': 1, 'S': 2, 'E': 2, 'C': 3},
              strengths: {
                'Mathematics': 5,
                'Physics': 5,
                'Electronics & Hardware': 5,
              },
              expected: 'Electrical Engineering',
            ),
            (
              group: 'Pre-Engineering (Math, Physics, Chemistry)',
              riasec: {'R': 5, 'I': 4, 'A': 2, 'S': 2, 'E': 2, 'C': 3},
              strengths: {
                'Mathematics': 5,
                'Physics': 5,
                'Technical Drawing & Design': 5,
                'Team Collaboration': 4,
              },
              expected: 'Mechanical Engineering',
            ),
            (
              group: 'Pre-Medical (Biology, Physics, Chemistry)',
              riasec: {'R': 2, 'I': 5, 'A': 1, 'S': 5, 'E': 3, 'C': 3},
              strengths: {
                'Biology': 5,
                'Chemistry': 5,
                'Critical Thinking': 5,
                'Communication & Empathy': 5,
                'Team Collaboration': 5,
              },
              expected: 'Medicine (MBBS)',
            ),
            (
              group: 'ICS (Computer Science, Math, Physics)',
              riasec: {'R': 2, 'I': 5, 'A': 2, 'S': 1, 'E': 1, 'C': 3},
              strengths: {
                'Computer Science': 5,
                'Mathematics': 5,
                'Logic & Problem Solving': 5,
                'Python Programming': 5,
                'System Design & Algorithms': 5,
              },
              expected: 'Computer Science',
            ),
            (
              group: 'ICS (Computer Science, Math, Physics)',
              riasec: {'R': 2, 'I': 3, 'A': 5, 'S': 3, 'E': 3, 'C': 2},
              strengths: {
                'Graphic Design & UI/UX': 5,
                'Web Development Basics': 5,
                'English': 4,
              },
              expected: 'Web & UI/UX Design',
            ),
            (
              group: 'I.Com (Commerce, Economics, Accounting)',
              riasec: {'R': 1, 'I': 2, 'A': 4, 'S': 4, 'E': 5, 'C': 2},
              strengths: {
                'Public Speaking': 5,
                'Business Studies': 5,
                'Team Collaboration': 5,
              },
              expected: 'Marketing & Sales',
            ),
            (
              group: 'Humanities / Arts',
              riasec: {'R': 1, 'I': 4, 'A': 2, 'S': 4, 'E': 5, 'C': 4},
              strengths: {
                'Civics & Political Science': 5,
                'English': 5,
                'Public Speaking': 5,
                'Critical Thinking': 5,
              },
              expected: 'Law',
            ),
            (
              group: 'Humanities / Arts',
              riasec: {'R': 4, 'I': 2, 'A': 4, 'S': 4, 'E': 2, 'C': 3},
              strengths: {'Home Economics': 5, 'Fine Arts': 4},
              expected: 'Home Economics (Food, Nutrition & Textiles)',
            ),
          ];

      for (final scenario in scenarios) {
        final skills = {
          for (final skill in SkillsScreen.skillNamesForEducationLevel(
            'Intermediate',
            specialization: scenario.group,
          ))
            skill: scenario.strengths[skill] ?? 1,
        };
        final recommendations = await _recommend(
          specialization: scenario.group,
          riasec: scenario.riasec,
          skills: skills,
        );
        expect(
          recommendations.first.title,
          scenario.expected,
          reason: scenario.group,
        );
      }
    },
  );
}

Future<List<CareerRecommendation>> _recommend({
  String educationLevel = 'Intermediate',
  required String specialization,
  required Map<String, int> riasec,
  required Map<String, int> skills,
}) {
  return const RecommendationService(
    unifiedModelRunner: FakeUnifiedModelRunner(),
  ).recommend(
    academicProfile: StudentAcademicProfile(
      educationLevel: educationLevel,
      specialization: specialization,
      academicScore: 84,
      scoreType: AcademicScoreType.percentage,
    ),
    riasecScores: riasec,
    skillRatings: skills,
  );
}
