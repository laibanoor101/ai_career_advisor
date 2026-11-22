import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/student_profile.dart';
import 'field_recommender.dart';
import 'recommendation_models.dart';
import 'stream_recommender.dart';
import 'tflite_recommender.dart';
import 'unified_model.dart';

export 'recommendation_models.dart';

class RecommendationService {
  const RecommendationService({
    CareerModelRunner? modelRunner,
    this.unifiedModelRunner,
  }) : _modelRunner = modelRunner ?? const TfliteRecommender();

  static const String _knowledgeAssetPath = 'assets/data/career_knowledge.json';
  static const String tfliteEngineName = 'tflite';
  static const String fallbackEngineName = 'fallback';
  static const String streamRulesEngineName = 'stream_rules';
  static const String streamRulesSubtitle = StreamRecommender.engineSubtitle;
  static const String tfliteSubtitle =
      'On-device AI model + expert rules (TFLite)';
  static const String fallbackSubtitle = 'Cosine similarity fallback';
  static const List<String> _riasecOrder = ['R', 'I', 'A', 'S', 'E', 'C'];
  static Future<_CareerKnowledge>? _knowledgeFuture;

  final CareerModelRunner _modelRunner;
  final UnifiedModelRunner? unifiedModelRunner;

  UnifiedModel get _unifiedModel {
    final runner = unifiedModelRunner;
    return runner == null
        ? UnifiedModel.instance
        : UnifiedModel.withRunner(runner);
  }

  static const Map<String, List<LearningResource>> _learningResources = {
    'Business Analyst': [
      LearningResource(
        title: 'Data Analysis with Python',
        provider: 'freeCodeCamp',
        url: 'https://www.freecodecamp.org/learn/data-analysis-with-python/',
      ),
      LearningResource(
        title: 'Excel for the web learning path',
        provider: 'Microsoft Learn',
        url: 'https://learn.microsoft.com/training/browse/?products=excel',
      ),
    ],
    'Clerk': [
      LearningResource(
        title: 'Microsoft 365 training',
        provider: 'Microsoft Support',
        url: 'https://support.microsoft.com/training',
      ),
      LearningResource(
        title: 'Business and accounting courses',
        provider: 'Khan Academy',
        url: 'https://www.khanacademy.org/economics-finance-domain',
      ),
    ],
    'Data Entry Operator': [
      LearningResource(
        title: 'Microsoft 365 training',
        provider: 'Microsoft Support',
        url: 'https://support.microsoft.com/training',
      ),
      LearningResource(
        title: 'SQLBolt interactive SQL lessons',
        provider: 'SQLBolt',
        url: 'https://sqlbolt.com/',
      ),
    ],
    'Financial Analyst': [
      LearningResource(
        title: 'Finance and capital markets',
        provider: 'Khan Academy',
        url: 'https://www.khanacademy.org/economics-finance-domain',
      ),
      LearningResource(
        title: 'Excel for the web learning path',
        provider: 'Microsoft Learn',
        url: 'https://learn.microsoft.com/training/browse/?products=excel',
      ),
    ],
    'Junior Accountant': [
      LearningResource(
        title: 'Accounting and financial statements',
        provider: 'Khan Academy',
        url: 'https://www.khanacademy.org/economics-finance-domain',
      ),
      LearningResource(
        title: 'Microsoft 365 training',
        provider: 'Microsoft Support',
        url: 'https://support.microsoft.com/training',
      ),
    ],
    'Marketing Executive': [
      LearningResource(
        title: 'Digital marketing courses',
        provider: 'HubSpot Academy',
        url: 'https://academy.hubspot.com/courses/marketing',
      ),
      LearningResource(
        title: 'Google Skillshop',
        provider: 'Google',
        url: 'https://skillshop.withgoogle.com/',
      ),
    ],
    'ML Engineer': [
      LearningResource(
        title: 'Machine Learning Crash Course',
        provider: 'Google for Developers',
        url: 'https://developers.google.com/machine-learning/crash-course',
      ),
      LearningResource(
        title: 'Kaggle Learn',
        provider: 'Kaggle',
        url: 'https://www.kaggle.com/learn',
      ),
    ],
    'Professor': [
      LearningResource(
        title: 'Teaching and learning resources',
        provider: 'OpenLearn',
        url: 'https://www.open.edu/openlearn/education-development',
      ),
      LearningResource(
        title: 'Academic writing',
        provider: 'Purdue OWL',
        url: 'https://owl.purdue.edu/owl/general_writing/academic_writing/',
      ),
    ],
    'Research Scientist': [
      LearningResource(
        title: 'Research methods courses',
        provider: 'OpenLearn',
        url: 'https://www.open.edu/openlearn/education-development',
      ),
      LearningResource(
        title: 'Statistics and probability',
        provider: 'Khan Academy',
        url: 'https://www.khanacademy.org/math/statistics-probability',
      ),
    ],
    'Sales Assistant': [
      LearningResource(
        title: 'Inbound sales certification',
        provider: 'HubSpot Academy',
        url: 'https://academy.hubspot.com/courses/inbound-sales',
      ),
      LearningResource(
        title: 'Communication skills',
        provider: 'OpenLearn',
        url: 'https://www.open.edu/openlearn/money-business/leadership-management',
      ),
    ],
    'School Counselor': [
      LearningResource(
        title: 'Psychology and mental health courses',
        provider: 'OpenLearn',
        url: 'https://www.open.edu/openlearn/health-sports-psychology',
      ),
      LearningResource(
        title: 'Psychology',
        provider: 'Khan Academy',
        url: 'https://www.khanacademy.org/test-prep/mcat/behavior',
      ),
    ],
    'Software Engineer': [
      LearningResource(
        title: 'CS50x: Introduction to Computer Science',
        provider: 'Harvard University',
        url: 'https://cs50.harvard.edu/x/',
      ),
      LearningResource(
        title: 'Developer roadmaps',
        provider: 'roadmap.sh',
        url: 'https://roadmap.sh/',
      ),
    ],
  };

  Future<List<CareerRecommendation>> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) async {
    final educationLevel = academicProfile.educationLevel.trim().toLowerCase();
    final unifiedModel = _unifiedModel;
    if (educationLevel == 'matric') {
      return const StreamRecommender().recommend(
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
        unifiedModel: unifiedModel,
      );
    }
    if (educationLevel == 'intermediate') {
      return const FieldRecommender().recommend(
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
        unifiedModel: unifiedModel,
      );
    }
    if (educationLevel == 'bachelors' || educationLevel == "bachelor's") {
      return const FieldRecommender(educationLevel: 'Bachelors').recommend(
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
        unifiedModel: unifiedModel,
      );
    }

    final knowledge = await (_knowledgeFuture ??= _loadKnowledge());
    late final String engineName;
    late final List<_ScoredCareer> rankedCareers;

    try {
      final modelScores = await _modelRunner.recommend(
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
      );
      rankedCareers = _rankModelScores(modelScores, knowledge);
      engineName = tfliteEngineName;
    } catch (error) {
      debugPrint(
        'TFLite recommendation failed; using cosine similarity fallback: '
        '$error',
      );
      rankedCareers = _rankByCosineSimilarity(
        knowledge: knowledge,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
      );
      engineName = fallbackEngineName;
    }

    debugPrint('Recommendation engine: $engineName');
    final academicScore = _academicPercentage(academicProfile);
    final recommendations = rankedCareers
        .take(5)
        .map((scored) {
          final career = knowledge.careers[scored.title]!;
          final skillGaps = _buildSkillGaps(
            career: career,
            skillRatings: skillRatings,
            skillsOrder: knowledge.skillsOrder,
          );
          return CareerRecommendation(
            title: scored.title,
            matchPercent: (scored.displayScore * 100).round().clamp(0, 100),
            engineName: engineName,
            typicalAcademicScore: career.typicalAcademicScore,
            alignmentDimensions: _buildAlignmentDimensions(
              career: career,
              riasecScores: riasecScores,
              skillRatings: skillRatings,
              skillsOrder: knowledge.skillsOrder,
              academicScore: academicScore,
            ),
            skillGaps: skillGaps,
            reasons: _buildReasons(
              careerTitle: scored.title,
              career: career,
              riasecScores: riasecScores,
              skillRatings: skillRatings,
              skillsOrder: knowledge.skillsOrder,
              academicScore: academicScore,
            ),
            missingSkills: skillGaps
                .where((skill) => skill.difference > 0)
                .map((skill) => skill.skillName)
                .toList(growable: false),
            learningResources:
                _learningResources[scored.title] ?? const <LearningResource>[],
          );
        })
        .toList(growable: false);
    return List.unmodifiable(recommendations);
  }

  static Future<_CareerKnowledge> _loadKnowledge() async {
    final contents = await rootBundle.loadString(_knowledgeAssetPath);
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Career knowledge must be a JSON object.');
    }
    return _CareerKnowledge.fromJson(decoded);
  }

  static List<_ScoredCareer> _rankModelScores(
    CareerModelScores scores,
    _CareerKnowledge knowledge,
  ) {
    if (scores.classes.length != 12 ||
        scores.rawProbabilities.length != scores.classes.length ||
        scores.displayProbabilities.length != scores.classes.length ||
        scores.rawProbabilities.any((value) => !value.isFinite || value < 0) ||
        scores.displayProbabilities.any(
          (value) => !value.isFinite || value < 0,
        )) {
      throw const FormatException('TFLite returned an invalid score vector.');
    }
    final scored = <_ScoredCareer>[];
    for (var index = 0; index < scores.classes.length; index++) {
      final title = scores.classes[index];
      if (!knowledge.careers.containsKey(title)) {
        throw FormatException('TFLite class "$title" has no career profile.');
      }
      scored.add(
        _ScoredCareer(
          title: title,
          rawScore: scores.rawProbabilities[index],
          displayScore: scores.displayProbabilities[index],
        ),
      );
    }
    scored.sort((first, second) => second.rawScore.compareTo(first.rawScore));
    return scored;
  }

  static List<_ScoredCareer> _rankByCosineSimilarity({
    required _CareerKnowledge knowledge,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) {
    final studentInterests = [
      for (final code in _riasecOrder) _scaleRating(riasecScores[code] ?? 1),
    ];
    final studentSkills = [
      for (final skill in knowledge.skillsOrder)
        _scaleRating(skillRatings[skill] ?? 1),
    ];
    final results = <_ScoredCareer>[];
    for (final entry in knowledge.careers.entries) {
      final careerInterests = [
        for (final value in entry.value.riasec) _scaleRating(value),
      ];
      final careerSkills = [
        for (final value in entry.value.skills) _scaleRating(value),
      ];
      final score =
          0.45 * _cosineSimilarity(studentInterests, careerInterests) +
          0.55 * _cosineSimilarity(studentSkills, careerSkills);
      results.add(
        _ScoredCareer(title: entry.key, rawScore: score, displayScore: score),
      );
    }
    results.sort((first, second) => second.rawScore.compareTo(first.rawScore));
    return results;
  }

  static List<CareerSkillGap> _buildSkillGaps({
    required _CareerProfile career,
    required Map<String, int> skillRatings,
    required List<String> skillsOrder,
  }) {
    final requirements = <CareerSkillGap>[];
    for (var index = 0; index < skillsOrder.length; index++) {
      final requiredLevel = career.skills[index];
      if (requiredLevel < 3) continue;
      requirements.add(
        CareerSkillGap(
          skillName: skillsOrder[index],
          currentLevel: (skillRatings[skillsOrder[index]] ?? 0)
              .clamp(0, 5)
              .toInt(),
          requiredLevel: requiredLevel,
        ),
      );
    }
    return List.unmodifiable(sortCareerSkillGaps(requirements).take(6));
  }

  static List<CareerAlignmentDimension> _buildAlignmentDimensions({
    required _CareerProfile career,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
    required List<String> skillsOrder,
    required double academicScore,
  }) {
    final interestIndices = List<int>.generate(6, (index) => index)
      ..sort(
        (first, second) =>
            career.riasec[second].compareTo(career.riasec[first]),
      );
    final skillIndices =
        List<int>.generate(
          skillsOrder.length,
          (index) => index,
        ).where((index) => career.skills[index] >= 3).toList()..sort(
          (first, second) =>
              career.skills[second].compareTo(career.skills[first]),
        );
    return List.unmodifiable([
      for (final index in interestIndices.take(2))
        CareerAlignmentDimension(
          label: _interestLabels[_riasecOrder[index]]!,
          studentValue:
              _scaleRating(riasecScores[_riasecOrder[index]] ?? 1) * 100,
          careerValue: _scaleRating(career.riasec[index]) * 100,
          code: _riasecOrder[index],
        ),
      CareerAlignmentDimension(
        label: 'Academics',
        studentValue: academicScore.clamp(0, 100).toDouble(),
        careerValue: career.typicalAcademicScore,
      ),
      for (final index in skillIndices.take(2))
        CareerAlignmentDimension(
          label: _shortSkillLabel(skillsOrder[index]),
          studentValue:
              ((skillRatings[skillsOrder[index]] ?? 0).clamp(0, 5) / 5) * 100,
          careerValue: (career.skills[index] / 5) * 100,
        ),
    ]);
  }

  static List<String> _buildReasons({
    required String careerTitle,
    required _CareerProfile career,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
    required List<String> skillsOrder,
    required double academicScore,
  }) {
    final strongestCode = _riasecOrder.reduce(
      (first, second) =>
          (riasecScores[first] ?? 1) >= (riasecScores[second] ?? 1)
          ? first
          : second,
    );
    final strongestTarget = career.riasec[_riasecOrder.indexOf(strongestCode)];
    final interestReason =
        'For $careerTitle, your strongest RIASEC code is $strongestCode '
        '(${(riasecScores[strongestCode] ?? 1).clamp(1, 5)}/5); '
        "this career's target for it is $strongestTarget/5.";

    final normalizedScore = academicScore.clamp(0, 100).round();
    final academicRelation = normalizedScore > career.typicalAcademicScore
        ? 'above'
        : normalizedScore < career.typicalAcademicScore
        ? 'below'
        : 'at';
    final academicReason =
        'For $careerTitle, your academic score of $normalizedScore% is $academicRelation '
        "this career's typical score of "
        '${career.typicalAcademicScore.round()}%.';

    final matchingSkills =
        [
          for (var index = 0; index < skillsOrder.length; index++)
            if (career.skills[index] >= 3 &&
                (skillRatings[skillsOrder[index]] ?? 0) > 0)
              (
                name: skillsOrder[index],
                required: career.skills[index],
                current: (skillRatings[skillsOrder[index]] ?? 0).clamp(0, 5),
              ),
        ]..sort((first, second) {
          final firstFit =
              math.min(first.current, first.required) / first.required;
          final secondFit =
              math.min(second.current, second.required) / second.required;
          final fitOrder = secondFit.compareTo(firstFit);
          if (fitOrder != 0) return fitOrder;
          return second.current.compareTo(first.current);
        });
    final skillReason = matchingSkills.isEmpty
        ? "No rated skill yet matches $careerTitle's required skill profile."
        : 'Your best matching $careerTitle skill is ${matchingSkills.first.name} '
              '(${matchingSkills.first.current}/5; '
              'career requirement ${matchingSkills.first.required}/5).';
    return List.unmodifiable([interestReason, academicReason, skillReason]);
  }

  static double _academicPercentage(StudentAcademicProfile profile) =>
      profile.scoreType == AcademicScoreType.cgpa
      ? profile.academicScore * 25
      : profile.academicScore;

  static double _scaleRating(int value) =>
      ((value.clamp(1, 5) - 1) / 4).toDouble();

  static double _cosineSimilarity(List<double> first, List<double> second) {
    var dotProduct = 0.0;
    var firstMagnitude = 0.0;
    var secondMagnitude = 0.0;
    for (var index = 0; index < first.length; index++) {
      dotProduct += first[index] * second[index];
      firstMagnitude += first[index] * first[index];
      secondMagnitude += second[index] * second[index];
    }
    if (firstMagnitude == 0 || secondMagnitude == 0) return 0;
    return dotProduct /
        (math.sqrt(firstMagnitude) * math.sqrt(secondMagnitude));
  }

  static String _shortSkillLabel(String skill) => switch (skill) {
    'Python Programming' ||
    'Logic & Problem Solving' ||
    'Mathematics & Calculus' => 'Coding/Logic',
    'Data Analysis & Statistics' => 'Data Analysis',
    'Database Querying (SQL)' => 'Database/SQL',
    'Accounting & Finance' => 'Accounting',
    _ => skill.split(' ').take(2).join(' '),
  };

  static const Map<String, String> _interestLabels = {
    'R': 'Realistic',
    'I': 'Investigative',
    'A': 'Artistic',
    'S': 'Social',
    'E': 'Enterprising',
    'C': 'Conventional',
  };
}

class _ScoredCareer {
  const _ScoredCareer({
    required this.title,
    required this.rawScore,
    required this.displayScore,
  });

  final String title;
  final double rawScore;
  final double displayScore;
}

class _CareerKnowledge {
  const _CareerKnowledge({required this.skillsOrder, required this.careers});

  final List<String> skillsOrder;
  final Map<String, _CareerProfile> careers;

  factory _CareerKnowledge.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skills_order'];
    final rawCareers = json['careers'];
    if (rawSkills is! List ||
        rawSkills.any((skill) => skill is! String) ||
        rawCareers is! Map ||
        rawCareers.keys.any((key) => key is! String)) {
      throw const FormatException('Career knowledge has an invalid schema.');
    }
    final skillsOrder = rawSkills.cast<String>();
    final careers = <String, _CareerProfile>{};
    for (final entry in rawCareers.entries) {
      if (entry.value is! Map) {
        throw FormatException('Invalid career profile "${entry.key}".');
      }
      careers[entry.key as String] = _CareerProfile.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
        skillsOrder.length,
      );
    }
    if (skillsOrder.length != 18 || careers.length != 12) {
      throw const FormatException('Career knowledge dimensions are invalid.');
    }
    return _CareerKnowledge(
      skillsOrder: List.unmodifiable(skillsOrder),
      careers: Map.unmodifiable(careers),
    );
  }
}

class _CareerProfile {
  const _CareerProfile({
    required this.riasec,
    required this.skills,
    required this.typicalAcademicScore,
  });

  final List<int> riasec;
  final List<int> skills;
  final double typicalAcademicScore;

  factory _CareerProfile.fromJson(Map<String, dynamic> json, int skillCount) {
    List<int> levels(String key, int expectedLength) {
      final value = json[key];
      if (value is! List ||
          value.length != expectedLength ||
          value.any((level) => level is! int || level < 1 || level > 5)) {
        throw FormatException('Invalid career profile field "$key".');
      }
      return List.unmodifiable(value.cast<int>());
    }

    final typicalScore = json['pct'];
    if (typicalScore is! num || typicalScore < 0 || typicalScore > 100) {
      throw const FormatException('Invalid career academic score.');
    }
    return _CareerProfile(
      riasec: levels('riasec', 6),
      skills: levels('skills', skillCount),
      typicalAcademicScore: typicalScore.toDouble(),
    );
  }
}
