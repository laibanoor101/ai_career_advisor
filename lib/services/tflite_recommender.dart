import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/student_profile.dart';

class CareerModelMetadata {
  const CareerModelMetadata({
    required this.inputSize,
    required this.classes,
    required this.featureOrder,
    required this.skillsOrder,
    required this.specializations,
    required this.educationLevels,
    required this.appGroupToSpecialization,
    required this.displayTemperature,
  });

  final int inputSize;
  final List<String> classes;
  final List<String> featureOrder;
  final List<String> skillsOrder;
  final List<String> specializations;
  final List<String> educationLevels;
  final Map<String, String> appGroupToSpecialization;
  final double displayTemperature;

  factory CareerModelMetadata.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) {
      final value = json[key];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Invalid model metadata field "$key".');
      }
      return List.unmodifiable(value.cast<String>());
    }

    final rawMapping = json['app_group_to_specialization'];
    if (rawMapping is! Map ||
        rawMapping.keys.any((key) => key is! String) ||
        rawMapping.values.any((value) => value is! String)) {
      throw const FormatException(
        'Invalid model metadata field "app_group_to_specialization".',
      );
    }
    final inputSize = json['input_size'];
    final temperature = json['display_temperature'];
    if (inputSize is! int || temperature is! num || temperature <= 0) {
      throw const FormatException('Invalid model input size or temperature.');
    }

    return CareerModelMetadata(
      inputSize: inputSize,
      classes: strings('classes'),
      featureOrder: strings('feature_order'),
      skillsOrder: strings('skills_order'),
      specializations: strings('specializations'),
      educationLevels: strings('education_levels'),
      appGroupToSpecialization: Map.unmodifiable(
        rawMapping.cast<String, String>(),
      ),
      displayTemperature: temperature.toDouble(),
    );
  }
}

class CareerModelScores {
  const CareerModelScores({
    required this.classes,
    required this.rawProbabilities,
    required this.displayProbabilities,
  });

  final List<String> classes;
  final List<double> rawProbabilities;
  final List<double> displayProbabilities;
}

abstract interface class CareerModelRunner {
  Future<CareerModelScores> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  });
}

class TfliteRecommender implements CareerModelRunner {
  const TfliteRecommender();

  static const String modelAssetPath = 'assets/models/career_model.tflite';
  static const String metadataAssetPath = 'assets/models/model_meta.json';
  static const List<String> riasecOrder = ['R', 'I', 'A', 'S', 'E', 'C'];

  static Future<CareerModelMetadata>? _metadataFuture;
  static Future<Interpreter>? _interpreterFuture;

  static Future<CareerModelMetadata> loadMetadata() {
    return _metadataFuture ??= rootBundle.loadString(metadataAssetPath).then((
      contents,
    ) {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Model metadata must be a JSON object.');
      }
      final metadata = CareerModelMetadata.fromJson(decoded);
      _validateMetadata(metadata);
      return metadata;
    });
  }

  @override
  Future<CareerModelScores> recommend({
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) async {
    if (Platform.isWindows) {
      throw UnsupportedError(
        'The TFLite native runtime is not packaged for Windows.',
      );
    }
    final metadata = await loadMetadata();
    final input = encodeInput(
      metadata: metadata,
      academicProfile: academicProfile,
      riasecScores: riasecScores,
      skillRatings: skillRatings,
    );
    final interpreter = await (_interpreterFuture ??= Interpreter.fromAsset(
      modelAssetPath,
    ));
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (inputShape.length != 2 ||
        inputShape[0] != 1 ||
        inputShape[1] != metadata.inputSize ||
        outputShape.length != 2 ||
        outputShape[0] != 1 ||
        outputShape[1] != metadata.classes.length) {
      throw FormatException(
        'Unexpected TFLite tensor shapes: input $inputShape, output $outputShape.',
      );
    }

    final output = [List<double>.filled(metadata.classes.length, 0)];
    interpreter.run([input], output);
    final rawProbabilities = output.single;
    if (rawProbabilities.any((value) => !value.isFinite || value < 0)) {
      throw const FormatException('TFLite returned invalid probabilities.');
    }
    return CareerModelScores(
      classes: metadata.classes,
      rawProbabilities: List.unmodifiable(rawProbabilities),
      displayProbabilities: List.unmodifiable(
        applyDisplayTemperature(rawProbabilities, metadata.displayTemperature),
      ),
    );
  }

  static List<double> encodeInput({
    required CareerModelMetadata metadata,
    required StudentAcademicProfile academicProfile,
    required Map<String, int> riasecScores,
    required Map<String, int> skillRatings,
  }) {
    final input = <double>[
      for (final code in riasecOrder) _scaleRating(riasecScores[code] ?? 1),
      for (final skill in metadata.skillsOrder)
        _scaleRating(skillRatings[skill] ?? 1),
      _normalizePercentage(_percentage(academicProfile)),
      _educationIndex(metadata, academicProfile.educationLevel) /
          (metadata.educationLevels.length - 1),
      for (final specialization in metadata.specializations)
        specialization ==
                _resolveSpecialization(metadata, academicProfile.specialization)
            ? 1
            : 0,
    ];
    if (input.length != metadata.inputSize ||
        input.any((value) => value < 0 || value > 1 || !value.isFinite)) {
      throw FormatException(
        'Encoded model input must contain ${metadata.inputSize} values in 0..1.',
      );
    }
    return List.unmodifiable(input);
  }

  static List<String> expectedFeatureOrder(CareerModelMetadata metadata) => [
    for (final code in riasecOrder) '(riasec_$code-1)/4',
    for (final skill in metadata.skillsOrder) '(skill_$skill-1)/4',
    '(percentage-50)/50 clipped 0..1',
    'education_index/2',
    for (final specialization in metadata.specializations)
      'specialization_$specialization',
  ];

  static List<double> applyDisplayTemperature(
    List<double> probabilities,
    double temperature,
  ) {
    if (probabilities.isEmpty || temperature <= 0) {
      throw ArgumentError('Probabilities and a positive temperature required.');
    }
    final adjusted = probabilities.map((probability) {
      if (!probability.isFinite || probability < 0) {
        throw ArgumentError('Probabilities must be finite and non-negative.');
      }
      return probability == 0
          ? 0.0
          : math.pow(probability, 1 / temperature).toDouble();
    }).toList();
    final total = adjusted.fold<double>(0, (sum, value) => sum + value);
    if (!total.isFinite || total <= 0) {
      throw ArgumentError('Probabilities must have a positive sum.');
    }
    return List.unmodifiable(adjusted.map((value) => value / total));
  }

  static double _percentage(StudentAcademicProfile profile) =>
      profile.scoreType == AcademicScoreType.cgpa
      ? profile.academicScore * 25
      : profile.academicScore;

  static double _normalizePercentage(double percentage) =>
      ((percentage - 50) / 50).clamp(0.0, 1.0).toDouble();

  static double _scaleRating(int rating) =>
      ((rating.clamp(1, 5) - 1) / 4).toDouble();

  static int _educationIndex(CareerModelMetadata metadata, String education) {
    final normalized = _normalize(education);
    final directIndex = metadata.educationLevels.indexWhere(
      (level) => _normalize(level) == normalized,
    );
    if (directIndex >= 0) return directIndex;
    final bachelorIndex = metadata.educationLevels.indexWhere(
      (level) => _normalize(level) == 'bachelors',
    );
    if (normalized.contains('bachelor') && bachelorIndex >= 0) {
      return bachelorIndex;
    }
    return _closestIndex(metadata.educationLevels, education);
  }

  static String _resolveSpecialization(
    CareerModelMetadata metadata,
    String source,
  ) {
    final normalized = _normalize(source);
    for (final specialization in metadata.specializations) {
      if (_normalize(specialization) == normalized) return specialization;
    }

    final exactGroup = metadata.appGroupToSpecialization.entries.where(
      (entry) => _normalize(entry.key) == normalized,
    );
    if (exactGroup.isNotEmpty &&
        metadata.specializations.contains(exactGroup.first.value)) {
      return exactGroup.first.value;
    }

    if (metadata.appGroupToSpecialization.isNotEmpty) {
      final closestGroup = metadata.appGroupToSpecialization.keys.reduce(
        (first, second) =>
            _distance(normalized, _normalize(first)) <=
                _distance(normalized, _normalize(second))
            ? first
            : second,
      );
      final mapped = metadata.appGroupToSpecialization[closestGroup];
      if (mapped != null && metadata.specializations.contains(mapped)) {
        return mapped;
      }
    }
    return metadata.specializations[_closestIndex(
      metadata.specializations,
      source,
    )];
  }

  static int _closestIndex(List<String> options, String source) {
    if (options.isEmpty) throw const FormatException('No metadata options.');
    final normalized = _normalize(source);
    var closestIndex = 0;
    var closestDistance = _distance(normalized, _normalize(options.first));
    for (var index = 1; index < options.length; index++) {
      final distance = _distance(normalized, _normalize(options[index]));
      if (distance < closestDistance) {
        closestIndex = index;
        closestDistance = distance;
      }
    }
    return closestIndex;
  }

  static int _distance(String first, String second) {
    final previous = List<int>.generate(second.length + 1, (index) => index);
    for (var firstIndex = 0; firstIndex < first.length; firstIndex++) {
      var diagonal = previous[0];
      previous[0] = firstIndex + 1;
      for (var secondIndex = 0; secondIndex < second.length; secondIndex++) {
        final above = previous[secondIndex + 1];
        previous[secondIndex + 1] = [
          previous[secondIndex + 1] + 1,
          previous[secondIndex] + 1,
          diagonal +
              (first.codeUnitAt(firstIndex) == second.codeUnitAt(secondIndex)
                  ? 0
                  : 1),
        ].reduce((first, second) => first < second ? first : second);
        diagonal = above;
      }
    }
    return previous.last;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static void _validateMetadata(CareerModelMetadata metadata) {
    if (metadata.inputSize != 33 ||
        metadata.featureOrder.length != metadata.inputSize ||
        metadata.classes.length != 12 ||
        metadata.skillsOrder.length != 18 ||
        metadata.educationLevels.length < 2 ||
        metadata.specializations.isEmpty) {
      throw const FormatException('Model metadata dimensions are invalid.');
    }
    final expected = expectedFeatureOrder(metadata);
    if (!_sameValues(metadata.featureOrder, expected)) {
      throw const FormatException(
        'Model metadata feature_order does not match the encoder.',
      );
    }
  }

  static bool _sameValues(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
