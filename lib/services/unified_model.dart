import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/student_profile.dart';
import 'tflite_recommender.dart';

abstract interface class UnifiedModelRunner {
  bool get isLoaded;

  Future<List<double>?> run(Float32List input);
}

class UnifiedModel {
  UnifiedModel._(this._runner);

  factory UnifiedModel.withRunner(UnifiedModelRunner runner) =>
      UnifiedModel._(runner);

  static final UnifiedModel instance = UnifiedModel._(
    const TfliteUnifiedModelRunner(),
  );

  static const String modelAssetPath =
      'assets/models/unified_career_model.tflite';
  static const String metadataAssetPath =
      'assets/models/unified_model_meta.json';

  static Future<UnifiedModelMetadata>? _metadataFuture;
  final UnifiedModelRunner _runner;

  bool get isLoaded => _runner.isLoaded;

  Future<UnifiedModelMetadata?> loadMetadata() async {
    try {
      return await (_metadataFuture ??= _loadMetadata());
    } catch (error) {
      debugPrint('Unified model metadata could not be loaded: $error');
      return null;
    }
  }

  Future<Map<String, double>?> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) async {
    try {
      final metadata = await loadMetadata();
      if (metadata == null) return null;
      final group = metadata.groupFor(
        academicProfile.educationLevel,
        academicProfile.specialization,
      );
      if (group == null) return null;
      final input = encodeInput(
        metadata: metadata,
        academicProfile: academicProfile,
        riasecScores: riasecScores,
        skillRatings: skillRatings,
      );
      if (input == null) return null;

      final probabilities = await _runner.run(input);
      if (probabilities == null ||
          probabilities.length != metadata.outputSize ||
          probabilities.any((value) => !value.isFinite || value < 0)) {
        return null;
      }

      final classProbabilities = <String, double>{};
      for (var index = 0; index < metadata.classes.length; index++) {
        classProbabilities[metadata.classes[index].key] = probabilities[index];
      }
      final selected = <String, double>{
        for (final key in group.classKeys)
          if (classProbabilities.containsKey(key))
            key: classProbabilities[key]!,
      };
      final total = selected.values.fold<double>(
        0,
        (sum, value) => sum + value,
      );
      if (selected.length != group.classKeys.length ||
          !total.isFinite ||
          total <= 0) {
        return null;
      }
      return Map.unmodifiable({
        for (final entry in selected.entries) entry.key: entry.value / total,
      });
    } catch (error) {
      debugPrint('Unified model recommendation failed: $error');
      return null;
    }
  }

  static Float32List? encodeInput({
    required UnifiedModelMetadata metadata,
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) {
    final group = metadata.groupFor(
      academicProfile.educationLevel,
      academicProfile.specialization,
    );
    if (group == null) return null;

    final offeredSkills = group.skills.toSet();
    final input = Float32List(metadata.inputSize);
    var index = 0;
    for (final code in metadata.riasecOrder) {
      input[index++] = _scale(riasecScores[code] ?? 1);
    }
    for (final skill in metadata.skillsOrder) {
      input[index++] = offeredSkills.contains(skill)
          ? _scale(skillRatings[skill] ?? 1)
          : 0;
    }
    for (final candidate in metadata.groups) {
      input[index++] = identical(candidate, group) ? 1 : 0;
    }
    if (index != metadata.inputSize ||
        input.any((value) => !value.isFinite || value < 0 || value > 1)) {
      return null;
    }
    return input;
  }

  static double _scale(int rating) => ((rating.clamp(1, 5) - 1) / 4).toDouble();

  static List<double>? blendProbabilities({
    required List<double> ruleProbabilities,
    required List<String> candidateKeys,
    required Map<String, double>? modelProbabilities,
    required double temperature,
    required double modelWeight,
  }) {
    if (modelProbabilities == null ||
        ruleProbabilities.length != candidateKeys.length ||
        ruleProbabilities.isEmpty ||
        candidateKeys.any((key) => !modelProbabilities.containsKey(key)) ||
        ruleProbabilities.any((value) => !value.isFinite || value < 0) ||
        modelWeight < 0 ||
        modelWeight > 1) {
      return null;
    }
    try {
      final calibratedModel = TfliteRecommender.applyDisplayTemperature([
        for (final key in candidateKeys) modelProbabilities[key]!,
      ], temperature);
      return List.unmodifiable([
        for (var index = 0; index < candidateKeys.length; index++)
          (1 - modelWeight) * ruleProbabilities[index] +
              modelWeight * calibratedModel[index],
      ]);
    } on ArgumentError {
      return null;
    }
  }

  static Future<UnifiedModelMetadata> _loadMetadata() async {
    final decoded = jsonDecode(await rootBundle.loadString(metadataAssetPath));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unified model metadata must be an object.');
    }
    return UnifiedModelMetadata.fromJson(decoded);
  }
}

class UnifiedModelMetadata {
  const UnifiedModelMetadata({
    required this.version,
    required this.inputSize,
    required this.outputSize,
    required this.riasecOrder,
    required this.skillsOrder,
    required this.groups,
    required this.classes,
    required this.displayTemperature,
    required this.hybridModelWeight,
  });

  final int version;
  final int inputSize;
  final int outputSize;
  final List<String> riasecOrder;
  final List<String> skillsOrder;
  final List<UnifiedModelGroup> groups;
  final List<UnifiedModelClass> classes;
  final double displayTemperature;
  final double hybridModelWeight;

  UnifiedModelGroup? groupFor(String educationLevel, String name) {
    final level = _canonicalLevel(educationLevel);
    for (final group in groups) {
      if (group.level == level && group.name == name) return group;
    }
    return null;
  }

  factory UnifiedModelMetadata.fromJson(Map<String, dynamic> json) {
    int integer(String field) {
      final value = json[field];
      if (value is! int) {
        throw FormatException('Invalid unified model field "$field".');
      }
      return value;
    }

    double number(String field) {
      final value = json[field];
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid unified model field "$field".');
      }
      return value.toDouble();
    }

    List<String> strings(String field) {
      final value = json[field];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Invalid unified model field "$field".');
      }
      return List.unmodifiable(value.cast<String>());
    }

    final rawClasses = json['classes'];
    if (rawClasses is! List) {
      throw const FormatException('Unified model classes must be a list.');
    }
    final classes = rawClasses
        .map((rawClass) {
          if (rawClass is! Map || rawClass.keys.any((key) => key is! String)) {
            throw const FormatException('Invalid unified model class entry.');
          }
          return UnifiedModelClass.fromJson(
            Map<String, dynamic>.from(rawClass),
          );
        })
        .toList(growable: false);
    final classesByIndex = classes;
    final classesByKey = {for (final item in classes) item.key: item};

    final rawGroups = json['groups'];
    if (rawGroups is! List) {
      throw const FormatException('Unified model groups must be a list.');
    }
    final groups = rawGroups
        .map((rawGroup) {
          if (rawGroup is! Map || rawGroup.keys.any((key) => key is! String)) {
            throw const FormatException('Invalid unified model group entry.');
          }
          final group = Map<String, dynamic>.from(rawGroup);
          final rawGroupClasses = group['classes'];
          if (rawGroupClasses is! List) {
            throw const FormatException(
              'Unified model group classes must be a list.',
            );
          }
          final classKeys = rawGroupClasses
              .map((item) {
                if (item is String && classesByKey.containsKey(item)) {
                  return item;
                }
                if (item is int && item >= 0 && item < classesByIndex.length) {
                  return classesByIndex[item].key;
                }
                throw const FormatException(
                  'Unified model group contains an unknown class.',
                );
              })
              .toList(growable: false);
          final skills = group['skills'];
          if (skills is! List || skills.any((item) => item is! String)) {
            throw const FormatException(
              'Unified model group skills must be a string list.',
            );
          }
          return UnifiedModelGroup(
            level: _requiredString(group['level'], 'group level'),
            name: _requiredString(group['name'], 'group name'),
            skills: List.unmodifiable(skills.cast<String>()),
            classKeys: List.unmodifiable(classKeys),
          );
        })
        .toList(growable: false);
    final metadata = UnifiedModelMetadata(
      version: integer('version'),
      inputSize: integer('input_size'),
      outputSize: integer('output_size'),
      riasecOrder: strings('riasec_order'),
      skillsOrder: strings('skills_order'),
      groups: List.unmodifiable(groups),
      classes: List.unmodifiable(classes),
      displayTemperature: number('display_temperature'),
      hybridModelWeight: number('hybrid_model_weight'),
    );
    if (metadata.version != 2 ||
        metadata.inputSize != 123 ||
        metadata.outputSize != 79 ||
        metadata.riasecOrder.length != 6 ||
        metadata.skillsOrder.length != 104 ||
        metadata.groups.length != 13 ||
        metadata.classes.length != metadata.outputSize ||
        metadata.displayTemperature <= 0 ||
        metadata.hybridModelWeight < 0 ||
        metadata.hybridModelWeight > 1 ||
        metadata.groups.any(
          (group) =>
              group.classKeys.isEmpty ||
              group.classKeys.toSet().length != group.classKeys.length,
        ) ||
        classesByKey.length != classes.length) {
      throw const FormatException(
        'Unified model metadata dimensions are invalid.',
      );
    }
    return metadata;
  }
}

class UnifiedModelGroup {
  const UnifiedModelGroup({
    required this.level,
    required this.name,
    required this.skills,
    required this.classKeys,
  });

  final String level;
  final String name;
  final List<String> skills;
  final List<String> classKeys;
}

class UnifiedModelClass {
  const UnifiedModelClass({
    required this.key,
    required this.level,
    required this.id,
    required this.title,
  });

  final String key;
  final String level;
  final String id;
  final String title;

  factory UnifiedModelClass.fromJson(Map<String, dynamic> json) =>
      UnifiedModelClass(
        key: _requiredString(json['key'], 'class key'),
        level: _requiredString(json['level'], 'class level'),
        id: _requiredString(json['id'], 'class id'),
        title: _requiredString(json['title'], 'class title'),
      );
}

class TfliteUnifiedModelRunner implements UnifiedModelRunner {
  const TfliteUnifiedModelRunner();

  static Future<Interpreter?>? _interpreterFuture;
  static bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<List<double>?> run(Float32List input) async {
    try {
      if (input.length != 123) return null;
      final interpreter = await (_interpreterFuture ??= _loadInterpreter());
      if (interpreter == null) return null;
      _loaded = true;
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (inputShape.length != 2 ||
          inputShape[0] != 1 ||
          inputShape[1] != 123 ||
          outputShape.length != 2 ||
          outputShape[0] != 1 ||
          outputShape[1] != 79) {
        debugPrint(
          'Unified TFLite tensor shapes are invalid: '
          'input $inputShape, output $outputShape.',
        );
        return null;
      }
      final output = [List<double>.filled(79, 0)];
      interpreter.run([input.toList(growable: false)], output);
      final probabilities = output.single;
      if (probabilities.any((value) => !value.isFinite || value < 0)) {
        debugPrint('Unified TFLite returned invalid probabilities.');
        return null;
      }
      return List.unmodifiable(probabilities);
    } catch (error) {
      debugPrint('Unified TFLite inference failed: $error');
      return null;
    }
  }

  static Future<Interpreter?> _loadInterpreter() async {
    try {
      return await Interpreter.fromAsset(UnifiedModel.modelAssetPath);
    } catch (error) {
      debugPrint('Unified TFLite model could not be loaded: $error');
      return null;
    }
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid unified model value "$field".');
  }
  return value;
}

String _canonicalLevel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'bachelor' || normalized == "bachelor's") {
    return 'Bachelors';
  }
  if (normalized == 'matric') return 'Matric';
  if (normalized == 'intermediate') return 'Intermediate';
  if (normalized == 'bachelors') return 'Bachelors';
  return value;
}
