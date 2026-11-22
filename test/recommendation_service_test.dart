import 'package:ai_career_advisor/models/student_profile.dart';
import 'package:ai_career_advisor/screens/skills_screen.dart';
import 'package:ai_career_advisor/services/recommendation_service.dart';
import 'package:ai_career_advisor/services/tflite_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_unified_model_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Bachelors uses expert field rules and never calls the TFLite runner',
    () async {
      final specialization = bachelorsSkillsByGroup.keys.first;
      final skills = {
        for (final skill in SkillsScreen.skillNamesForEducationLevel(
          'Bachelors',
          specialization: specialization,
        ))
          skill: 3,
      };
      final recommendations =
          await const RecommendationService(
            modelRunner: _UnexpectedModel(),
            unifiedModelRunner: FakeUnifiedModelRunner(),
          ).recommend(
            academicProfile: StudentAcademicProfile(
              educationLevel: 'Bachelors',
              specialization: specialization,
              academicScore: 3.2,
              scoreType: AcademicScoreType.cgpa,
            ),
            riasecScores: const {
              'R': 3,
              'I': 5,
              'A': 3,
              'S': 2,
              'E': 3,
              'C': 4,
            },
            skillRatings: skills,
          );

      expect(recommendations, hasLength(5));
      expect(
        recommendations.map((career) => career.title).toSet(),
        hasLength(5),
      );
      for (final recommendation in recommendations) {
        expect(recommendation.title, isNotEmpty);
        expect(recommendation.matchPercent, inInclusiveRange(0, 100));
        expect(
          recommendation.engineName,
          RecommendationService.streamRulesEngineName,
        );
        expect(recommendation.reasons, hasLength(1));
        expect(recommendation.learningResources, hasLength(2));
        expect(recommendation.typicalAcademicScore, 0);
        expect(
          recommendation.alignmentDimensions.every(
            (dimension) => dimension.label != 'Academics',
          ),
          isTrue,
        );
      }
    },
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
    throw StateError('Bachelors recommendations must not use TFLite.');
  }
}
