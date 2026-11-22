import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/student_profile.dart';
import 'recommendation_models.dart';
import 'tflite_recommender.dart';
import 'unified_model.dart';

class StreamRecommender {
  const StreamRecommender();

  static const String engineName = 'stream_rules';
  static const String engineSubtitle = 'Expert rule-based career matcher';
  static const String _knowledgeAssetPath = 'assets/data/stream_knowledge.json';
  static const List<String> _riasecOrder = ['R', 'I', 'A', 'S', 'E', 'C'];
  static const List<String> _skillsOrder = [
    'English',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'General Science',
    'Civics',
    'Economics',
    'History',
    'Education',
    'Home Economics',
    'Geography',
  ];
  static const Map<String, String> _interestLabels = {
    'R': 'Realistic',
    'I': 'Investigative',
    'A': 'Artistic',
    'S': 'Social',
    'E': 'Enterprising',
    'C': 'Conventional',
  };
  static Future<List<_StudyPath>>? _knowledgeFuture;

  Future<List<CareerRecommendation>> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
    UnifiedModel? unifiedModel,
  }) async {
    final model = unifiedModel ?? UnifiedModel.instance;
    final paths = await (_knowledgeFuture ??= _loadKnowledge());
    final metadata = await model.loadMetadata();
    final scoredPaths = [
      for (final path in paths)
        (
          path: path,
          score:
              0.5 *
                  _cosineSimilarity(
                    [
                      for (final code in _riasecOrder)
                        _scale(riasecScores[code] ?? 1),
                    ],
                    [
                      for (final code in _riasecOrder)
                        _scale(path.riasecTargets[code]!),
                    ],
                  ) +
              0.5 *
                  _cosineSimilarity(
                    [
                      for (final skill in _skillsOrder)
                        if (skillRatings.containsKey(skill))
                          _scale(skillRatings[skill]!),
                    ],
                    [
                      for (final skill in _skillsOrder)
                        if (skillRatings.containsKey(skill))
                          _scale(path.skills[skill]!),
                    ],
                  ) +
              (_groupBonus(academicProfile.specialization, path) ? 0.05 : 0),
        ),
    ];
    final rawScores = scoredPaths.map((item) => item.score).toList();
    final ruleProbabilities = TfliteRecommender.applyDisplayTemperature(
      rawScores.every((score) => score == 0)
          ? List<double>.filled(rawScores.length, 1)
          : rawScores,
      metadata?.displayTemperature ?? 3.0,
    );
    Map<String, double>? modelProbabilities;
    try {
      modelProbabilities = await model.recommend(
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
      );
    } catch (error) {
      debugPrint('Unified model scoring failed; using rules only: $error');
    }
    final hybridScores = UnifiedModel.blendProbabilities(
      candidateKeys: [for (final item in scoredPaths) 'Matric:${item.path.id}'],
      ruleProbabilities: ruleProbabilities,
      modelProbabilities: modelProbabilities,
      temperature: metadata?.displayTemperature ?? 3.0,
      modelWeight: metadata?.hybridModelWeight ?? 0.5,
    );
    final usedHybrid = hybridScores != null;
    final displayScores = hybridScores ?? ruleProbabilities;
    final engine = usedHybrid ? 'tflite' : engineName;
    debugPrint(
      'Recommendation engine: $engine; unified model loaded: ${model.isLoaded}',
    );
    final rankedPaths = [
      for (var index = 0; index < scoredPaths.length; index++)
        (
          path: scoredPaths[index].path,
          score: usedHybrid ? displayScores[index] : scoredPaths[index].score,
          displayScore: displayScores[index],
        ),
    ]..sort((first, second) => second.score.compareTo(first.score));

    return List.unmodifiable([
      for (final ranked in rankedPaths.take(5))
        _buildRecommendation(
          ranked.path,
          ranked.displayScore,
          riasecScores,
          skillRatings,
          engine,
        ),
    ]);
  }

  static Future<List<_StudyPath>> _loadKnowledge() async {
    final contents = await rootBundle.loadString(_knowledgeAssetPath);
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stream knowledge must be a JSON object.');
    }

    final riasecOrder = _stringList(decoded['riasec_order'], 'riasec_order');
    final skillsOrder = _stringList(decoded['skills_order'], 'skills_order');
    if (!_sameValues(riasecOrder, _riasecOrder) ||
        !_sameValues(skillsOrder, _skillsOrder)) {
      throw const FormatException(
        'Stream knowledge dimensions do not match the supported profile.',
      );
    }
    final rawPaths = decoded['paths'];
    if (rawPaths is! List || rawPaths.length != 6) {
      throw const FormatException('Stream knowledge must contain six paths.');
    }
    final paths = rawPaths
        .map((rawPath) {
          if (rawPath is! Map || rawPath.keys.any((key) => key is! String)) {
            throw const FormatException('Invalid study path entry.');
          }
          return _StudyPath.fromJson(Map<String, dynamic>.from(rawPath));
        })
        .toList(growable: false);
    if (paths.map((path) => path.id).toSet().length != paths.length) {
      throw const FormatException('Study path ids must be unique.');
    }
    return List.unmodifiable(paths);
  }

  static List<String> _stringList(Object? value, String field) {
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Invalid stream knowledge field "$field".');
    }
    return value.cast<String>();
  }

  static CareerRecommendation _buildRecommendation(
    _StudyPath path,
    double displayScore,
    Map<String, int> riasecScores,
    Map<String, int> skillRatings,
    String engine,
  ) {
    final offeredSkills = _skillsOrder
        .where(skillRatings.containsKey)
        .toList(growable: false);
    final skillGaps = sortCareerSkillGaps([
      for (final skill in offeredSkills)
        if (path.skills[skill]! >= 3)
          CareerSkillGap(
            skillName: skill,
            currentLevel: skillRatings[skill]!.clamp(1, 5).toInt(),
            requiredLevel: path.skills[skill]!,
          ),
    ]);
    final rankedInterests = _riasecOrder.toList()
      ..sort(
        (first, second) =>
            path.riasecTargets[second]!.compareTo(path.riasecTargets[first]!),
      );
    final rankedSkills =
        offeredSkills.where((skill) => path.skills[skill]! >= 3).toList()..sort(
          (first, second) =>
              path.skills[second]!.compareTo(path.skills[first]!),
        );

    return CareerRecommendation(
      title: path.title,
      subtitle: path.subtitle,
      leadsTo: path.careers,
      matchPercent: (displayScore * 100).round().clamp(0, 100),
      engineName: engine,
      typicalAcademicScore: 0,
      alignmentDimensions: [
        for (final code in rankedInterests.take(3))
          CareerAlignmentDimension(
            label: _interestLabels[code]!,
            studentValue: _scale(riasecScores[code] ?? 1) * 100,
            careerValue: _scale(path.riasecTargets[code]!) * 100,
            code: code,
          ),
        for (final skill in rankedSkills.take(2))
          CareerAlignmentDimension(
            label: skill,
            studentValue: _scale(skillRatings[skill]!) * 100,
            careerValue: _scale(path.skills[skill]!) * 100,
          ),
      ],
      skillGaps: skillGaps,
      reasons: [path.reasonTemplate.replaceAll('{subtitle}', path.subtitle)],
      missingSkills: [
        for (final gap in skillGaps)
          if (gap.difference > 0) gap.skillName,
      ],
      learningResources: path.resources,
    );
  }

  static bool _groupBonus(String specialization, _StudyPath path) {
    return switch (specialization) {
      'Science Group (Bio-Science)' => path.id == 'pre-medical',
      'General Science Group (Computer Science)' =>
        path.id == 'ics' || path.id == 'pre-engineering',
      'Arts / Humanities & Home Economics Group' =>
        path.id == 'fa-humanities' || path.id == 'fa-arts-home-economics',
      _ => false,
    };
  }

  static double _scale(int rating) => ((rating.clamp(1, 5) - 1) / 4).toDouble();

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

  static bool _sameValues(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

class _StudyPath {
  const _StudyPath({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.riasecTargets,
    required this.skills,
    required this.reasonTemplate,
    required this.careers,
    required this.resources,
  });

  final String id;
  final String title;
  final String subtitle;
  final Map<String, int> riasecTargets;
  final Map<String, int> skills;
  final String reasonTemplate;
  final List<String> careers;
  final List<LearningResource> resources;

  factory _StudyPath.fromJson(Map<String, dynamic> json) {
    String string(String field) {
      final value = json[field];
      if (value is! String || value.isEmpty) {
        throw FormatException('Invalid study path field "$field".');
      }
      return value;
    }

    Map<String, int> ratings(String field, List<String> keys) {
      final raw = json[field];
      if (raw is! Map ||
          raw.keys.any((key) => key is! String) ||
          raw.keys.toSet().length != keys.length ||
          raw.keys.toSet().difference(keys.toSet()).isNotEmpty ||
          keys.any(
            (key) =>
                raw[key] is! int ||
                (raw[key] as int) < 1 ||
                (raw[key] as int) > 5,
          )) {
        throw FormatException('Invalid study path field "$field".');
      }
      return Map.unmodifiable(raw.cast<String, int>());
    }

    final careers = StreamRecommender._stringList(json['careers'], 'careers');
    final rawResources = json['resources'];
    if (rawResources is! List || rawResources.length != 2) {
      throw const FormatException(
        'Each study path must include two resources.',
      );
    }
    final resources = rawResources
        .map((rawResource) {
          if (rawResource is! Map ||
              rawResource.keys.any((key) => key is! String)) {
            throw const FormatException('Invalid study path resource.');
          }
          final resource = Map<String, dynamic>.from(rawResource);
          String requiredString(String field) {
            final value = resource[field];
            if (value is! String || value.isEmpty) {
              throw FormatException(
                'Invalid study path resource field "$field".',
              );
            }
            return value;
          }

          return LearningResource(
            title: requiredString('title'),
            provider: requiredString('provider'),
            url: requiredString('url'),
          );
        })
        .toList(growable: false);

    return _StudyPath(
      id: string('id'),
      title: string('title'),
      subtitle: string('subtitle'),
      riasecTargets: ratings('riasec_targets', StreamRecommender._riasecOrder),
      skills: ratings('skills', StreamRecommender._skillsOrder),
      reasonTemplate: string('reason_template'),
      careers: List.unmodifiable(careers),
      resources: List.unmodifiable(resources),
    );
  }
}
