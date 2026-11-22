import 'package:ai_career_advisor/services/history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AssessmentRecord serializes and restores all assessment fields', () {
    final createdAt = DateTime.utc(2025, 5, 6, 12, 30);
    final record = AssessmentRecord(
      id: 'assessment-1',
      createdAt: createdAt,
      educationLevel: 'Intermediate',
      group: 'Pre-Engineering',
      percentage: 82.5,
      riasecScores: const {'R': 3, 'I': 5, 'A': 2, 'S': 4, 'E': 3, 'C': 1},
      skills: const {'Python Programming': 4, 'Communication': 3},
      top5: const [
        AssessmentCareerMatch(title: 'Software Engineer', matchPercent: 87),
        AssessmentCareerMatch(title: 'Data Analyst', matchPercent: 74),
      ],
      topCareer: 'Software Engineer',
      engine: 'tflite',
    );

    final restored = AssessmentRecord.fromMap(record.toMap());

    expect(restored.id, record.id);
    expect(restored.createdAt, createdAt);
    expect(restored.educationLevel, record.educationLevel);
    expect(restored.group, record.group);
    expect(restored.percentage, record.percentage);
    expect(restored.riasecScores, record.riasecScores);
    expect(restored.skills, record.skills);
    expect(restored.top5.map((match) => match.toMap()).toList(), [
      {'title': 'Software Engineer', 'matchPercent': 87},
      {'title': 'Data Analyst', 'matchPercent': 74},
    ]);
    expect(restored.topCareer, record.topCareer);
    expect(restored.engine, record.engine);
  });

  test('AssessmentRecord restores legacy Matric group and skill names', () {
    final record = AssessmentRecord(
      id: 'matric-assessment',
      createdAt: DateTime.utc(2026, 11, 14),
      educationLevel: 'Matric',
      group: 'Science Group (Biology, Chemistry, Physics)',
      percentage: 88,
      riasecScores: const {'R': 2, 'I': 5, 'A': 2, 'S': 4, 'E': 2, 'C': 3},
      skills: const {'Biology & Medical Terms': 5},
      top5: const [
        AssessmentCareerMatch(title: 'Pre-Medical', matchPercent: 70),
      ],
      topCareer: 'Pre-Medical',
      engine: 'stream_rules',
    );

    final restored = AssessmentRecord.fromMap(record.toMap());

    expect(restored.engine, 'stream_rules');
    expect(restored.educationLevel, 'Matric');
    expect(restored.group, 'Science Group (Biology, Chemistry, Physics)');
    expect(restored.skills, const {'Biology & Medical Terms': 5});
    expect(restored.topCareer, 'Pre-Medical');
    expect(restored.top5.single.matchPercent, 70);
  });
}
