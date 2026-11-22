class CareerRecommendation {
  const CareerRecommendation({
    required this.title,
    required this.matchPercent,
    required this.engineName,
    required this.alignmentDimensions,
    required this.typicalAcademicScore,
    required this.skillGaps,
    required this.reasons,
    required this.missingSkills,
    required this.learningResources,
    this.subtitle,
    this.leadsTo = const [],
  });

  final String title;
  final int matchPercent;
  final String engineName;
  final List<CareerAlignmentDimension> alignmentDimensions;
  final double typicalAcademicScore;
  final List<CareerSkillGap> skillGaps;
  final List<String> reasons;
  final List<String> missingSkills;
  final List<LearningResource> learningResources;
  final String? subtitle;
  final List<String> leadsTo;

  Map<String, Object> toJson() => {
    'title': title,
    'matchPercent': matchPercent,
    'engineName': engineName,
    'typicalAcademicScore': typicalAcademicScore,
    'skillGaps': skillGaps.map((gap) => gap.toJson()).toList(),
    'reasons': reasons,
    'missingSkills': missingSkills,
    'learningResources': learningResources
        .map((item) => item.toJson())
        .toList(),
    'subtitle': ?subtitle,
    if (leadsTo.isNotEmpty) 'leadsTo': leadsTo,
  };
}

class CareerAlignmentDimension {
  const CareerAlignmentDimension({
    required this.label,
    required this.studentValue,
    required this.careerValue,
    this.code,
  });

  final String label;
  final double studentValue;
  final double careerValue;
  final String? code;
}

class CareerSkillGap {
  const CareerSkillGap({
    required this.skillName,
    required this.currentLevel,
    required this.requiredLevel,
  });

  final String skillName;
  final int currentLevel;
  final int requiredLevel;

  int get difference => requiredLevel - currentLevel;

  SkillGapStatus get status => switch (difference) {
    >= 2 => SkillGapStatus.needsAttention,
    1 => SkillGapStatus.developing,
    _ => SkillGapStatus.matchedStrength,
  };

  Map<String, Object> toJson() => {
    'skillName': skillName,
    'currentLevel': currentLevel,
    'requiredLevel': requiredLevel,
    'status': status.name,
  };
}

enum SkillGapStatus { needsAttention, developing, matchedStrength }

List<CareerSkillGap> sortCareerSkillGaps(Iterable<CareerSkillGap> gaps) {
  final sorted = gaps.toList()
    ..sort((first, second) {
      final requirementOrder = second.requiredLevel.compareTo(
        first.requiredLevel,
      );
      if (requirementOrder != 0) return requirementOrder;
      return first.skillName.toLowerCase().compareTo(
        second.skillName.toLowerCase(),
      );
    });
  return List.unmodifiable(sorted);
}

class LearningResource {
  const LearningResource({
    required this.title,
    required this.provider,
    required this.url,
  });

  final String title;
  final String provider;
  final String url;

  Map<String, String> toJson() => {
    'title': title,
    'provider': provider,
    'url': url,
  };
}
