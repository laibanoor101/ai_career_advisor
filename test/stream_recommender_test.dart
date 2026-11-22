import 'package:ai_career_advisor/models/student_profile.dart';
import 'package:ai_career_advisor/screens/skills_screen.dart';
import 'package:ai_career_advisor/services/recommendation_service.dart';
import 'package:ai_career_advisor/services/tflite_recommender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_unified_model_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = RecommendationService(
    modelRunner: _UnexpectedModel(),
    unifiedModelRunner: FakeUnifiedModelRunner(),
  );

  test('Matric exposes only the subjects for its selected group', () {
    expect(
      SkillsScreen.skillNamesForEducationLevel(
        'Matric',
        specialization: 'Science Group (Bio-Science)',
      ),
      ['English', 'Mathematics', 'Physics', 'Chemistry', 'Biology'],
    );
    expect(
      SkillsScreen.skillNamesForEducationLevel(
        'Matric',
        specialization: 'General Science Group (Computer Science)',
      ),
      ['English', 'Mathematics', 'Physics', 'Chemistry', 'Computer Science'],
    );
    expect(
      SkillsScreen.skillNamesForEducationLevel(
        'Matric',
        specialization: 'Arts / Humanities & Home Economics Group',
      ),
      [
        'English',
        'Mathematics',
        'General Science',
        'Civics',
        'Economics',
        'History',
        'Education',
        'Home Economics',
        'Geography',
      ],
    );
    for (final group in [
      'Science Group (Bio-Science)',
      'General Science Group (Computer Science)',
      'Arts / Humanities & Home Economics Group',
    ]) {
      final subjects = SkillsScreen.skillNamesForEducationLevel(
        'Matric',
        specialization: group,
      );
      expect(
        subjects,
        isNot(
          anyOf(
            contains('Urdu'),
            contains('Islamiat'),
            contains('Pakistan Studies'),
            contains('Graphic Design & UI/UX'),
          ),
        ),
      );
    }

    expect(SkillsScreen.skillNames, hasLength(18));
    expect(
      SkillsScreen.skillNamesForEducationLevel(
        'Bachelors',
        specialization: 'BS Software Engineering / Computer Science',
      ),
      bachelorsSkillsByGroup['BS Software Engineering / Computer Science']!.map(
        (skill) => skill.name,
      ),
    );
    expect(SkillsScreen.skillNamesForEducationLevel('Intermediate'), isEmpty);
  });

  testWidgets('Matric screen renders only the selected group subjects', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const groups = {
      'Science Group (Bio-Science)': [
        'English',
        'Mathematics',
        'Physics',
        'Chemistry',
        'Biology',
      ],
      'General Science Group (Computer Science)': [
        'English',
        'Mathematics',
        'Physics',
        'Chemistry',
        'Computer Science',
      ],
      'Arts / Humanities & Home Economics Group': [
        'English',
        'Mathematics',
        'General Science',
        'Civics',
        'Economics',
        'History',
        'Education',
        'Home Economics',
        'Geography',
      ],
    };
    for (final entry in groups.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsScreen(
            key: ValueKey(entry.key),
            academicProfile: StudentAcademicProfile(
              educationLevel: 'Matric',
              specialization: entry.key,
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

      expect(
        find.text('Search subjects (e.g. Biology, Math)...'),
        findsOneWidget,
      );
      for (final subject in entry.value) {
        expect(find.text(subject), findsOneWidget);
      }
      expect(find.text('Urdu'), findsNothing);
      expect(find.text('Islamiat'), findsNothing);
      expect(find.text('Pakistan Studies'), findsNothing);
      expect(find.text('Graphic Design & UI/UX'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  test('strong Biology and Chemistry profile recommends Pre-Medical', () async {
    final recommendations = await _recommend(
      service,
      specialization: 'Science Group (Bio-Science)',
      riasec: const {'R': 2, 'I': 5, 'A': 2, 'S': 4, 'E': 2, 'C': 3},
      skills: const {
        'English': 3,
        'Mathematics': 3,
        'Physics': 4,
        'Chemistry': 5,
        'Biology': 5,
      },
    );

    expect(recommendations.first.title, 'Pre-Medical');
    expect(
      recommendations.first.skillGaps.map((gap) => gap.skillName),
      everyElement(
        anyOf('English', 'Mathematics', 'Physics', 'Chemistry', 'Biology'),
      ),
    );
  });

  test('strong Computer Science and Mathematics profile recommends ICS or Pre-Engineering', () async {
    final recommendations = await _recommend(
      service,
      specialization: 'General Science Group (Computer Science)',
      riasec: const {'R': 3, 'I': 5, 'A': 3, 'S': 2, 'E': 2, 'C': 3},
      skills: const {
        'English': 3,
        'Mathematics': 5,
        'Physics': 4,
        'Chemistry': 2,
        'Computer Science': 5,
      },
    );

    expect(['ICS', 'Pre-Engineering'], contains(recommendations.first.title));
  });

  test('strong Arts profile recommends FA Humanities', () async {
    final recommendations = await _recommend(
      service,
      specialization: 'Arts / Humanities & Home Economics Group',
      riasec: const {'R': 1, 'I': 3, 'A': 4, 'S': 5, 'E': 3, 'C': 2},
      skills: const {
        'English': 5,
        'Mathematics': 2,
        'General Science': 2,
        'Civics': 5,
        'Economics': 3,
        'History': 5,
        'Education': 4,
        'Home Economics': 1,
        'Geography': 3,
      },
    );

    expect(recommendations.first.title, 'FA Humanities');
  });

  test('strong Home Economics Arts profile recommends FA Arts', () async {
    final recommendations = await _recommend(
      service,
      specialization: 'Arts / Humanities & Home Economics Group',
      riasec: const {'R': 2, 'I': 2, 'A': 5, 'S': 4, 'E': 3, 'C': 2},
      skills: const {
        'English': 4,
        'Mathematics': 2,
        'General Science': 2,
        'Civics': 2,
        'Economics': 2,
        'History': 3,
        'Education': 3,
        'Home Economics': 5,
        'Geography': 3,
      },
    );

    expect(recommendations.first.title, 'FA Arts and Home Economics');
  });

  test('strong Arts economics profile recommends I.Com', () async {
    final recommendations = await _recommend(
      service,
      specialization: 'Arts / Humanities & Home Economics Group',
      riasec: const {'R': 2, 'I': 3, 'A': 2, 'S': 3, 'E': 5, 'C': 5},
      skills: const {
        'English': 4,
        'Mathematics': 4,
        'General Science': 1,
        'Civics': 2,
        'Economics': 5,
        'History': 1,
        'Education': 2,
        'Home Economics': 1,
        'Geography': 3,
      },
    );

    expect(recommendations.first.title, 'I.Com');
  });

  test(
    'Intermediate uses field recommendations, not the TFLite runner',
    () async {
      final recommendations = await _recommend(
        service,
        educationLevel: 'Intermediate',
        specialization: 'ICS (Computer Science, Math, Physics)',
        riasec: const {'R': 2, 'I': 5, 'A': 2, 'S': 1, 'E': 1, 'C': 3},
        skills: const {
          'Computer Science': 5,
          'Mathematics': 5,
          'Physics': 1,
          'English': 1,
          'Logic & Problem Solving': 5,
          'Python Programming': 5,
          'Web Development Basics': 1,
          'Database Querying (SQL)': 1,
          'System Design & Algorithms': 5,
          'Data Analysis & Statistics': 1,
          'Graphic Design & UI/UX': 1,
          'Team Collaboration': 1,
        },
      );

      expect(recommendations.first.title, 'Computer Science');
      expect(
        recommendations.first.engineName,
        RecommendationService.streamRulesEngineName,
      );
      expect(recommendations, hasLength(5));
    },
  );
}

Future<List<CareerRecommendation>> _recommend(
  RecommendationService service, {
  String educationLevel = 'Matric',
  required String specialization,
  required Map<String, int> riasec,
  required Map<String, int> skills,
}) {
  return service.recommend(
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

class _UnexpectedModel implements CareerModelRunner {
  const _UnexpectedModel();

  @override
  Future<CareerModelScores> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) {
    throw StateError('The TFLite runner must not be used by these tests.');
  }
}
