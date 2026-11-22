import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/student_profile.dart';
import '../screens/academic_profile_screen.dart';
import 'recommendation_models.dart';
import 'stream_recommender.dart';
import 'tflite_recommender.dart';
import 'unified_model.dart';

class FieldRecommender {
  const FieldRecommender({this.educationLevel = 'Intermediate'});

  static const String engineName = StreamRecommender.engineName;
  static const List<String> _riasecOrder = ['R', 'I', 'A', 'S', 'E', 'C'];
  static const Map<String, String> _interestLabels = {
    'R': 'Realistic',
    'I': 'Investigative',
    'A': 'Artistic',
    'S': 'Social',
    'E': 'Enterprising',
    'C': 'Conventional',
  };
  static final Map<String, Future<List<_FieldGroup>>> _knowledgeFutures = {};

  final String educationLevel;

  String get _normalizedEducationLevel => educationLevel.trim().toLowerCase();

  String get _educationLabel => _normalizedEducationLevel == 'intermediate'
      ? 'Intermediate'
      : 'Bachelors';

  Future<List<CareerRecommendation>> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
    UnifiedModel? unifiedModel,
  }) async {
    final model = unifiedModel ?? UnifiedModel.instance;
    final groups = await (_knowledgeFutures[_normalizedEducationLevel] ??=
        _loadKnowledge(_normalizedEducationLevel));
    _FieldGroup? group;
    for (final candidate in groups) {
      if (candidate.name == academicProfile.specialization) {
        group = candidate;
        break;
      }
    }
    if (group == null) {
      throw FormatException(
        'No $_educationLabel knowledge group matches '
        '"${academicProfile.specialization}".',
      );
    }

    final metadata = await model.loadMetadata();
    final scoredFields = [
      for (final field in group.fields)
        (
          field: field,
          score:
              0.5 *
                  _cosineSimilarity(
                    [
                      for (final code in _riasecOrder)
                        _scale(riasecScores[code] ?? 1),
                    ],
                    [
                      for (final code in _riasecOrder)
                        _scale(field.riasecTargets[code]!),
                    ],
                  ) +
              0.5 *
                  _cosineSimilarity(
                    [
                      for (final skill in group.skills)
                        if (skillRatings.containsKey(skill.name))
                          _scale(skillRatings[skill.name]!),
                    ],
                    [
                      for (final skill in group.skills)
                        if (skillRatings.containsKey(skill.name))
                          _scale(field.skills[skill.name]!),
                    ],
                  ),
        ),
    ];
    final rawScores = scoredFields.map((item) => item.score).toList();
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
      candidateKeys: [
        for (final item in scoredFields) '$_educationLabel:${item.field.id}',
      ],
      ruleProbabilities: ruleProbabilities,
      modelProbabilities: modelProbabilities,
      temperature: metadata?.displayTemperature ?? 3.0,
      modelWeight: metadata?.hybridModelWeight ?? 0.5,
    );
    final usedHybrid = hybridScores != null;
    final displayScores = hybridScores ?? ruleProbabilities;
    final engine = usedHybrid ? 'tflite' : StreamRecommender.engineName;
    debugPrint(
      'Recommendation engine: $engine; unified model loaded: ${model.isLoaded}',
    );
    final rankedFields = [
      for (var index = 0; index < scoredFields.length; index++)
        (
          field: scoredFields[index].field,
          score: usedHybrid ? displayScores[index] : scoredFields[index].score,
          displayScore: displayScores[index],
        ),
    ]..sort((first, second) => second.score.compareTo(first.score));

    return List.unmodifiable([
      for (final ranked in rankedFields.take(5))
        _buildRecommendation(
          ranked.field,
          ranked.displayScore,
          riasecScores,
          skillRatings,
          engine,
        ),
    ]);
  }

  static Future<List<_FieldGroup>> _loadKnowledge(String educationLevel) async {
    if (educationLevel != 'intermediate' &&
        educationLevel != 'bachelors' &&
        educationLevel != "bachelor's") {
      throw ArgumentError.value(
        educationLevel,
        'educationLevel',
        'Expected Intermediate or Bachelors.',
      );
    }
    final knowledgeAssetPath = educationLevel == 'intermediate'
        ? 'assets/data/intermediate_knowledge.json'
        : 'assets/data/bachelors_knowledge.json';
    final educationLabel = educationLevel == 'intermediate'
        ? 'Intermediate'
        : 'Bachelors';
    final contents = await rootBundle.loadString(knowledgeAssetPath);
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Field knowledge must be a JSON object.');
    }
    final riasecOrder = _stringList(decoded['riasec_order'], 'riasec_order');
    if (!_sameValues(riasecOrder, _riasecOrder)) {
      throw const FormatException(
        'Field RIASEC dimensions do not match the supported profile.',
      );
    }

    final rawGroups = decoded['groups'];
    final expectedGroups = academicSpecializationOptions[educationLabel]!;
    if (rawGroups is! List || rawGroups.length != expectedGroups.length) {
      throw FormatException(
        '$educationLabel knowledge must contain exactly five groups.',
      );
    }
    final groups = rawGroups
        .map((rawGroup) {
          if (rawGroup is! Map || rawGroup.keys.any((key) => key is! String)) {
            throw FormatException('Invalid $educationLabel group entry.');
          }
          return _FieldGroup.fromJson(
            Map<String, dynamic>.from(rawGroup),
            educationLabel: educationLabel,
          );
        })
        .toList(growable: false);
    if (groups.map((group) => group.name).toSet().length != groups.length ||
        groups
            .map((group) => group.name)
            .toSet()
            .difference(expectedGroups.toSet())
            .isNotEmpty ||
        expectedGroups
            .toSet()
            .difference(groups.map((group) => group.name).toSet())
            .isNotEmpty) {
      throw FormatException(
        '$educationLabel knowledge group names do not match the available options.',
      );
    }
    if (educationLabel == 'Bachelors' &&
        groups.any((group) => group.skills.length != 14)) {
      throw const FormatException(
        'Each Bachelors knowledge group must contain exactly 14 skills.',
      );
    }
    final fieldIds = [
      for (final group in groups)
        for (final field in group.fields) field.id,
    ];
    if (fieldIds.toSet().length != fieldIds.length) {
      throw FormatException('$educationLabel field ids must be unique.');
    }
    return List.unmodifiable(groups);
  }

  static List<String> _stringList(Object? value, String field) {
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Invalid knowledge field "$field".');
    }
    return value.cast<String>();
  }

  static CareerRecommendation _buildRecommendation(
    _CareerField field,
    double displayScore,
    Map<String, int> riasecScores,
    Map<String, int> skillRatings,
    String engine,
  ) {
    final offeredSkills = field.skills.keys
        .where(skillRatings.containsKey)
        .toList(growable: false);
    final skillGaps = sortCareerSkillGaps([
      for (final skill in offeredSkills)
        if (field.skills[skill]! >= 3)
          CareerSkillGap(
            skillName: skill,
            currentLevel: skillRatings[skill]!.clamp(1, 5).toInt(),
            requiredLevel: field.skills[skill]!,
          ),
    ]);
    final rankedInterests = _riasecOrder.toList()
      ..sort(
        (first, second) =>
            field.riasecTargets[second]!.compareTo(field.riasecTargets[first]!),
      );
    final rankedSkills =
        offeredSkills.where((skill) => field.skills[skill]! >= 3).toList()
          ..sort(
            (first, second) =>
                field.skills[second]!.compareTo(field.skills[first]!),
          );

    return CareerRecommendation(
      title: field.title,
      subtitle: field.subtitle,
      leadsTo: field.careers,
      matchPercent: (displayScore * 100).round().clamp(0, 100),
      engineName: engine,
      typicalAcademicScore: 0,
      alignmentDimensions: [
        for (final code in rankedInterests.take(3))
          CareerAlignmentDimension(
            label: _interestLabels[code]!,
            studentValue: _scale(riasecScores[code] ?? 1) * 100,
            careerValue: _scale(field.riasecTargets[code]!) * 100,
            code: code,
          ),
        for (final skill in rankedSkills.take(2))
          CareerAlignmentDimension(
            label: skill,
            studentValue: _scale(skillRatings[skill]!) * 100,
            careerValue: _scale(field.skills[skill]!) * 100,
          ),
      ],
      skillGaps: skillGaps,
      reasons: [field.reasonTemplate.replaceAll('{subtitle}', field.subtitle)],
      missingSkills: [
        for (final gap in skillGaps)
          if (gap.difference > 0) gap.skillName,
      ],
      learningResources: field.resources,
    );
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

class _FieldGroup {
  const _FieldGroup({
    required this.name,
    required this.skills,
    required this.fields,
  });

  final String name;
  final List<_GroupSkill> skills;
  final List<_CareerField> fields;

  factory _FieldGroup.fromJson(
    Map<String, dynamic> json, {
    required String educationLabel,
  }) {
    final name = _requiredString(json['group'], 'group');
    final rawSkills = json['skills'];
    if (rawSkills is! List) {
      throw FormatException('Invalid $educationLabel group skills.');
    }
    final skills = rawSkills
        .map((rawSkill) {
          if (rawSkill is! Map || rawSkill.keys.any((key) => key is! String)) {
            throw FormatException('Invalid $educationLabel skill entry.');
          }
          final skill = Map<String, dynamic>.from(rawSkill);
          final skillName = _requiredString(skill['name'], 'skill name');
          final category = _requiredString(skill['category'], 'skill category');
          final hintValue = skill['hint'];
          if (skill.containsKey('hint') && hintValue is! String) {
            throw FormatException('Invalid hint for skill "$skillName".');
          }
          final hint = hintValue as String? ?? '';
          if (!const {'Tech', 'Analytical', 'Soft'}.contains(category)) {
            throw FormatException(
              'Invalid category "$category" for skill "$skillName".',
            );
          }
          return _GroupSkill(name: skillName, category: category, hint: hint);
        })
        .toList(growable: false);
    final skillNames = skills.map((skill) => skill.name).toSet();
    if (skillNames.length != skills.length) {
      throw FormatException(
        '$educationLabel group "$name" has duplicate skills.',
      );
    }

    final rawFields = json['fields'];
    if (rawFields is! List || rawFields.isEmpty) {
      throw FormatException('$educationLabel group "$name" has no fields.');
    }
    final fields = rawFields
        .map((rawField) {
          if (rawField is! Map || rawField.keys.any((key) => key is! String)) {
            throw FormatException('Invalid $educationLabel field entry.');
          }
          return _CareerField.fromJson(
            Map<String, dynamic>.from(rawField),
            skillNames,
            educationLabel: educationLabel,
          );
        })
        .toList(growable: false);
    return _FieldGroup(
      name: name,
      skills: List.unmodifiable(skills),
      fields: List.unmodifiable(fields),
    );
  }
}

class _GroupSkill {
  const _GroupSkill({
    required this.name,
    required this.category,
    this.hint = '',
  });

  final String name;
  final String category;
  final String hint;
}

class _CareerField {
  const _CareerField({
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

  factory _CareerField.fromJson(
    Map<String, dynamic> json,
    Set<String> groupSkillNames, {
    required String educationLabel,
  }) {
    final id = _requiredString(json['id'], 'id');
    final title = _requiredString(json['title'], 'title');
    final subtitle = _requiredString(json['subtitle'], 'subtitle');
    final riasecTargets = _ratings(
      json['riasec_targets'],
      FieldRecommender._riasecOrder.toSet(),
      'riasec_targets',
      educationLabel,
    );
    final skills = _ratings(
      json['skills'],
      groupSkillNames,
      'skills',
      educationLabel,
    );
    final reasonTemplate = _requiredString(
      json['reason_template'],
      'reason_template',
    );
    final careers = FieldRecommender._stringList(json['careers'], 'careers');
    final rawResources = json['resources'];
    if (rawResources is! List || rawResources.length != 2) {
      throw FormatException(
        '$educationLabel field "$title" must include exactly two resources.',
      );
    }
    final resources = rawResources
        .map((rawResource) {
          if (rawResource is! Map ||
              rawResource.keys.any((key) => key is! String)) {
            throw FormatException('Invalid $educationLabel learning resource.');
          }
          final resource = Map<String, dynamic>.from(rawResource);
          return LearningResource(
            title: _requiredString(resource['title'], 'resource title'),
            provider: _requiredString(
              resource['provider'],
              'resource provider',
            ),
            url: _requiredString(resource['url'], 'resource url'),
          );
        })
        .toList(growable: false);
    return _CareerField(
      id: id,
      title: title,
      subtitle: subtitle,
      riasecTargets: Map.unmodifiable(riasecTargets),
      skills: Map.unmodifiable(skills),
      reasonTemplate: reasonTemplate,
      careers: List.unmodifiable(careers),
      resources: List.unmodifiable(resources),
    );
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid field knowledge value "$field".');
  }
  return value;
}

Map<String, int> _ratings(
  Object? value,
  Set<String> expectedKeys,
  String field,
  String educationLabel,
) {
  if (value is! Map ||
      value.keys.any((key) => key is! String) ||
      value.keys.toSet().length != expectedKeys.length ||
      value.keys.toSet().difference(expectedKeys).isNotEmpty ||
      expectedKeys.difference(value.keys.cast<String>().toSet()).isNotEmpty ||
      value.values.any(
        (rating) => rating is! int || rating < 1 || rating > 5,
      )) {
    throw FormatException('Invalid $educationLabel rating map "$field".');
  }
  return value.cast<String, int>();
}
