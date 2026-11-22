import 'package:ai_career_advisor/models/student_profile.dart';
import 'package:ai_career_advisor/services/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_unified_model_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('skill gap statuses follow red, amber, and green thresholds', () {
    expect(
      const CareerSkillGap(
        skillName: 'Critical skill',
        currentLevel: 1,
        requiredLevel: 3,
      ).status,
      SkillGapStatus.needsAttention,
    );
    expect(
      const CareerSkillGap(
        skillName: 'Developing skill',
        currentLevel: 2,
        requiredLevel: 3,
      ).status,
      SkillGapStatus.developing,
    );
    expect(
      const CareerSkillGap(
        skillName: 'Matched skill',
        currentLevel: 4,
        requiredLevel: 3,
      ).status,
      SkillGapStatus.matchedStrength,
    );
  });

  test('skill gaps sort by required level and then skill name', () {
    final sorted = sortCareerSkillGaps([
      const CareerSkillGap(
        skillName: 'Matched',
        currentLevel: 3,
        requiredLevel: 3,
      ),
      const CareerSkillGap(
        skillName: 'Developing',
        currentLevel: 2,
        requiredLevel: 3,
      ),
      const CareerSkillGap(
        skillName: 'Zebra',
        currentLevel: 1,
        requiredLevel: 3,
      ),
      const CareerSkillGap(
        skillName: 'Alpha',
        currentLevel: 0,
        requiredLevel: 2,
      ),
    ]);

    expect(sorted.map((skill) => skill.skillName), [
      'Developing',
      'Matched',
      'Zebra',
      'Alpha',
    ]);
  });

  test(
    'skill gaps use expert levels and keep the strongest requirements',
    () async {
      final recommendations =
          await const RecommendationService(
            unifiedModelRunner: FakeUnifiedModelRunner(),
          ).recommend(
            academicProfile: const StudentAcademicProfile(
              educationLevel: 'Bachelors',
              specialization: 'BS Software Engineering / Computer Science',
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
            skillRatings: const {
              'Programming Fundamentals': 4,
              'Data Structures & Algorithms': 4,
              'Database Management': 3,
            },
          );

      expect(recommendations, hasLength(5));
      for (final career in recommendations) {
        expect(career.skillGaps.length, lessThanOrEqualTo(6));
        for (final skill in career.skillGaps) {
          expect(skill.requiredLevel, inInclusiveRange(3, 5));
          expect(skill.currentLevel, inInclusiveRange(0, 5));
        }
        for (var index = 1; index < career.skillGaps.length; index++) {
          expect(
            career.skillGaps[index - 1].requiredLevel,
            greaterThanOrEqualTo(career.skillGaps[index].requiredLevel),
          );
        }
      }
    },
  );
}
