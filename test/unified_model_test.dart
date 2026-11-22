import 'dart:convert';

import 'package:ai_career_advisor/models/student_profile.dart';
import 'package:ai_career_advisor/screens/academic_profile_screen.dart';
import 'package:ai_career_advisor/screens/skills_screen.dart';
import 'package:ai_career_advisor/services/recommendation_service.dart';
import 'package:ai_career_advisor/services/unified_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_unified_model_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UnifiedModelMetadata metadata;

  setUpAll(() async {
    metadata = (await UnifiedModel.instance.loadMetadata())!;
  });

  test('unified encoder follows the metadata feature order', () {
    const academicProfile = StudentAcademicProfile(
      educationLevel: 'Bachelors',
      specialization: 'BS Software Engineering / Computer Science',
      academicScore: 3.2,
      scoreType: AcademicScoreType.cgpa,
    );
    const riasecScores = {'R': 1, 'I': 2, 'A': 3, 'S': 4, 'E': 5, 'C': 1};
    const skillRatings = {
      'Programming Fundamentals': 5,
      'Data Structures & Algorithms': 2,
      'Biology': 5,
    };

    final input = UnifiedModel.encodeInput(
      metadata: metadata,
      academicProfile: academicProfile,
      riasecScores: riasecScores,
      skillRatings: skillRatings,
    )!;

    expect(input, hasLength(123));
    expect(input.every((value) => value >= 0 && value <= 1), isTrue);
    expect(input.take(6), [0, 0.25, 0.5, 0.75, 1, 0]);

    final programmingIndex =
        6 + metadata.skillsOrder.indexOf('Programming Fundamentals');
    final dsaIndex =
        6 + metadata.skillsOrder.indexOf('Data Structures & Algorithms');
    final biologyIndex = 6 + metadata.skillsOrder.indexOf('Biology');
    expect(input[programmingIndex], 1);
    expect(input[dsaIndex], 0.25);
    expect(input[biologyIndex], 0);

    final groupIndex = metadata.groups.indexWhere(
      (group) => group.name == academicProfile.specialization,
    );
    expect(input.skip(110).toList(), [
      for (var index = 0; index < metadata.groups.length; index++)
        index == groupIndex ? 1 : 0,
    ]);
    expect(
      UnifiedModel.encodeInput(
        metadata: metadata,
        academicProfile: const StudentAcademicProfile(
          educationLevel: 'Bachelors',
          specialization: '',
          academicScore: 0,
          scoreType: AcademicScoreType.cgpa,
        ),
        riasecScores: riasecScores,
        skillRatings: skillRatings,
      ),
      isNull,
    );
  });

  test('metadata groups, classes, and skills match app knowledge', () async {
    for (final group in metadata.groups) {
      expect(
        academicSpecializationOptions[group.level],
        contains(group.name),
        reason: '${group.level} ${group.name}',
      );
      final screenSkills = SkillsScreen.skillNamesForEducationLevel(
        group.level,
        specialization: group.name,
      );
      expect(
        group.skills.toSet(),
        containsAll(screenSkills),
        reason: '${group.level} ${group.name} skills',
      );
    }

    final stream = await _readJson('assets/data/stream_knowledge.json');
    final intermediate = await _readJson(
      'assets/data/intermediate_knowledge.json',
    );
    final bachelors = await _readJson('assets/data/bachelors_knowledge.json');
    final idsByLevel = <String, Set<String>>{
      'Matric': {
        for (final path in stream['paths'] as List<dynamic>)
          (path as Map<String, dynamic>)['id'] as String,
      },
      'Intermediate': _fieldIds(intermediate),
      'Bachelors': _fieldIds(bachelors),
    };
    for (final careerClass in metadata.classes) {
      expect(
        idsByLevel[careerClass.level],
        contains(careerClass.id),
        reason: careerClass.key,
      );
    }
  });

  test(
    'model probabilities include only the selected group and sum to one',
    () async {
      const academicProfile = StudentAcademicProfile(
        educationLevel: 'Intermediate',
        specialization: 'ICS (Computer Science, Math, Physics)',
        academicScore: 84,
        scoreType: AcademicScoreType.percentage,
      );
      final group = metadata.groupFor(
        academicProfile.educationLevel,
        academicProfile.specialization,
      )!;
      final output = List<double>.filled(metadata.outputSize, 0.001);
      for (final key in group.classKeys) {
        final index = metadata.classes.indexWhere((item) => item.key == key);
        output[index] = key == group.classKeys.first ? 0.9 : 0.1;
      }
      final model = UnifiedModel.withRunner(
        FakeUnifiedModelRunner(probabilities: output),
      );

      final probabilities = await model.recommend(
        academicProfile: academicProfile,
        riasecScores: const {'R': 3, 'I': 3, 'A': 3, 'S': 3, 'E': 3, 'C': 3},
        skillRatings: const {},
      );

      expect(probabilities!.keys.toSet(), group.classKeys.toSet());
      expect(
        probabilities.values.fold<double>(0, (sum, value) => sum + value),
        closeTo(1, 1e-12),
      );
    },
  );

  test('hybrid blending preserves normalized probability totals', () {
    final blended = UnifiedModel.blendProbabilities(
      ruleProbabilities: const [0.6, 0.3, 0.1],
      candidateKeys: const [
        'Intermediate:a',
        'Intermediate:b',
        'Intermediate:c',
      ],
      modelProbabilities: const {
        'Intermediate:a': 0.01,
        'Intermediate:b': 0.98,
        'Intermediate:c': 0.01,
      },
      temperature: 3,
      modelWeight: 0.5,
    )!;

    expect(
      blended.fold<double>(0, (sum, value) => sum + value),
      closeTo(1, 1e-12),
    );
    expect(blended[1], greaterThan(blended[0]));
    expect(blended[0], greaterThan(blended[2]));
  });

  test(
    'hybrid ranking uses the model for Matric, Intermediate, and Bachelors',
    () async {
      final scenarios = [
        (
          profile: const StudentAcademicProfile(
            educationLevel: 'Matric',
            specialization: 'Science Group (Bio-Science)',
            academicScore: 84,
            scoreType: AcademicScoreType.percentage,
          ),
          skills: SkillsScreen.skillNamesForEducationLevel(
            'Matric',
            specialization: 'Science Group (Bio-Science)',
          ),
        ),
        (
          profile: const StudentAcademicProfile(
            educationLevel: 'Intermediate',
            specialization: 'ICS (Computer Science, Math, Physics)',
            academicScore: 84,
            scoreType: AcademicScoreType.percentage,
          ),
          skills: SkillsScreen.skillNamesForEducationLevel(
            'Intermediate',
            specialization: 'ICS (Computer Science, Math, Physics)',
          ),
        ),
        (
          profile: const StudentAcademicProfile(
            educationLevel: 'Bachelors',
            specialization: 'BS Software Engineering / Computer Science',
            academicScore: 3.2,
            scoreType: AcademicScoreType.cgpa,
          ),
          skills: SkillsScreen.skillNamesForEducationLevel(
            'Bachelors',
            specialization: 'BS Software Engineering / Computer Science',
          ),
        ),
      ];

      for (final scenario in scenarios) {
        final riasec = const {'R': 3, 'I': 4, 'A': 3, 'S': 2, 'E': 3, 'C': 4};
        final skillRatings = {for (final skill in scenario.skills) skill: 3};
        final rulesOnly = await _recommend(
          scenario.profile,
          riasec,
          skillRatings,
          const FakeUnifiedModelRunner(),
        );
        final target = rulesOnly.last.title;
        final group = metadata.groupFor(
          scenario.profile.educationLevel,
          scenario.profile.specialization,
        )!;
        final targetClass = metadata.classes.firstWhere(
          (item) => group.classKeys.contains(item.key) && item.title == target,
        );
        final output = List<double>.filled(metadata.outputSize, 1e-12);
        output[metadata.classes.indexOf(targetClass)] = 1;
        final hybrid = await _recommend(
          scenario.profile,
          riasec,
          skillRatings,
          FakeUnifiedModelRunner(probabilities: output),
        );

        expect(
          hybrid.first.title,
          target,
          reason: scenario.profile.educationLevel,
        );
        expect(rulesOnly.first.title, isNot(target));
        expect(
          hybrid.every(
            (item) => item.engineName == RecommendationService.tfliteEngineName,
          ),
          isTrue,
        );
        for (var index = 1; index < hybrid.length; index++) {
          expect(
            hybrid[index - 1].matchPercent,
            greaterThanOrEqualTo(hybrid[index].matchPercent),
          );
        }
      }
    },
  );

  test('null and throwing runners preserve exact rules-only results', () async {
    const profile = StudentAcademicProfile(
      educationLevel: 'Intermediate',
      specialization: 'Pre-Medical (Biology, Physics, Chemistry)',
      academicScore: 84,
      scoreType: AcademicScoreType.percentage,
    );
    const riasec = {'R': 2, 'I': 5, 'A': 2, 'S': 5, 'E': 3, 'C': 3};
    final skills = {
      for (final skill in SkillsScreen.skillNamesForEducationLevel(
        'Intermediate',
        specialization: profile.specialization,
      ))
        skill: 3,
    };
    final nullResult = await _recommend(
      profile,
      riasec,
      skills,
      const FakeUnifiedModelRunner(),
    );
    final thrownResult = await _recommend(
      profile,
      riasec,
      skills,
      const FakeUnifiedModelRunner(throwOnRun: true),
    );

    expect(
      thrownResult.map((item) => (item.title, item.matchPercent)).toList(),
      nullResult.map((item) => (item.title, item.matchPercent)).toList(),
    );
    expect(
      [...nullResult, ...thrownResult].every(
        (item) =>
            item.engineName == RecommendationService.streamRulesEngineName,
      ),
      isTrue,
    );
  });
}

Future<Map<String, dynamic>> _readJson(String path) async =>
    jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;

Set<String> _fieldIds(Map<String, dynamic> knowledge) => {
  for (final group in knowledge['groups'] as List<dynamic>)
    for (final field
        in (group as Map<String, dynamic>)['fields'] as List<dynamic>)
      (field as Map<String, dynamic>)['id'] as String,
};

Future<List<CareerRecommendation>> _recommend(
  StudentAcademicProfile profile,
  Map<String, int> riasec,
  Map<String, int> skills,
  FakeUnifiedModelRunner runner,
) => RecommendationService(unifiedModelRunner: runner).recommend(
  academicProfile: profile,
  riasecScores: riasec,
  skillRatings: skills,
);
