import 'package:ai_career_advisor/models/student_profile.dart';
import 'package:ai_career_advisor/screens/academic_profile_screen.dart';
import 'package:ai_career_advisor/screens/skills_screen.dart';
import 'package:ai_career_advisor/services/tflite_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const academicProfile = StudentAcademicProfile(
    educationLevel: 'Intermediate',
    specialization: 'Pre-Engineering (Math, Physics, Chemistry)',
    academicScore: 84,
    scoreType: AcademicScoreType.percentage,
  );
  const riasecScores = {'R': 3, 'I': 5, 'A': 3, 'S': 2, 'E': 3, 'C': 4};

  test('encoder creates 33 normalized values', () async {
    final metadata = await TfliteRecommender.loadMetadata();
    final input = TfliteRecommender.encodeInput(
      metadata: metadata,
      academicProfile: academicProfile,
      riasecScores: riasecScores,
      skillRatings: {for (final skill in metadata.skillsOrder) skill: 3},
    );

    expect(input, hasLength(33));
    expect(input.every((value) => value >= 0 && value <= 1), isTrue);
  });

  test('metadata feature order matches the encoder order', () async {
    final metadata = await TfliteRecommender.loadMetadata();
    expect(
      metadata.featureOrder,
      TfliteRecommender.expectedFeatureOrder(metadata),
    );
  });

  test('metadata skill order matches the Skills screen catalog', () async {
    final metadata = await TfliteRecommender.loadMetadata();
    expect(metadata.skillsOrder, SkillsScreen.skillNames);
  });

  test('TFLite metadata maps all non-Matric groups', () async {
    final metadata = await TfliteRecommender.loadMetadata();
    final nonMatricOptions = academicSpecializationOptions.entries
        .where((entry) => entry.key != 'Matric')
        .expand((entry) => entry.value)
        .toSet();

    expect(metadata.appGroupToSpecialization, hasLength(13));
    expect(
      metadata.appGroupToSpecialization.keys,
      containsAll(nonMatricOptions),
    );
    for (final specialization in metadata.appGroupToSpecialization.values) {
      expect(metadata.specializations, contains(specialization));
    }

    final encoded = TfliteRecommender.encodeInput(
      metadata: metadata,
      academicProfile: const StudentAcademicProfile(
        educationLevel: 'Intermediate',
        specialization: 'Pre-Engineering (Math, Physics, Chemistry)',
        academicScore: 84,
        scoreType: AcademicScoreType.percentage,
      ),
      riasecScores: riasecScores,
      skillRatings: const {},
    );
    expect(encoded.skip(26).where((value) => value == 1), hasLength(1));

    final unknownGroup = TfliteRecommender.encodeInput(
      metadata: metadata,
      academicProfile: const StudentAcademicProfile(
        educationLevel: 'Intermediate',
        specialization: 'Unknown science group',
        academicScore: 84,
        scoreType: AcademicScoreType.percentage,
      ),
      riasecScores: riasecScores,
      skillRatings: const {},
    );
    expect(unknownGroup, hasLength(33));
    expect(unknownGroup.skip(26).where((value) => value == 1), hasLength(1));
  });

  test('temperature output sums to one and preserves ranking order', () {
    final calibrated = TfliteRecommender.applyDisplayTemperature([
      0.8,
      0.15,
      0.05,
    ], 3);

    expect(
      calibrated.fold<double>(0, (sum, value) => sum + value),
      closeTo(1, 1e-12),
    );
    expect(calibrated[0], greaterThan(calibrated[1]));
    expect(calibrated[1], greaterThan(calibrated[2]));
  });
}
