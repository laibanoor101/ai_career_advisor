enum AcademicScoreType { percentage, cgpa }

class StudentAcademicProfile {
  const StudentAcademicProfile({
    required this.educationLevel,
    required this.specialization,
    required this.academicScore,
    required this.scoreType,
  });

  final String educationLevel;
  final String specialization;
  final double academicScore;
  final AcademicScoreType scoreType;
}
