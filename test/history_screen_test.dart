import 'package:ai_career_advisor/constants/app_theme.dart';
import 'package:ai_career_advisor/screens/history_screen.dart';
import 'package:ai_career_advisor/services/history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty history shows the helper card and start action', (
    tester,
  ) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HistoryScreen(
            repository: _MemoryHistoryRepository(const []),
            onViewMatches: (_) {},
            onStartAssessment: () => started = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No assessments yet'), findsOneWidget);
    expect(
      find.text('Your saved career matches will appear here.'),
      findsOneWidget,
    );
    expect(find.text('Start Assessment'), findsOneWidget);
    await tester.tap(find.text('Start Assessment'));
    expect(started, isTrue);
  });

  testWidgets('history lists two saved assessments newest first', (
    tester,
  ) async {
    final newest = _record(
      id: 'newest',
      createdAt: DateTime(2026, 11, 14, 12, 41),
      career: 'Newest Career',
      percent: 94,
      others: const [
        AssessmentCareerMatch(title: 'New Other One', matchPercent: 82),
        AssessmentCareerMatch(title: 'New Other Two', matchPercent: 76),
      ],
    );
    final older = _record(
      id: 'older',
      createdAt: DateTime(2026, 10, 14, 16, 30),
      career: 'Older Career',
      percent: 86,
      others: const [
        AssessmentCareerMatch(title: 'Old Other One', matchPercent: 74),
        AssessmentCareerMatch(title: 'Old Other Two', matchPercent: 69),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HistoryScreen(
            repository: _MemoryHistoryRepository([newest, older]),
            onViewMatches: (_) {},
            onStartAssessment: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 saved assessments'), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('14 Nov 2026 · 12:41 PM'), findsOneWidget);
    expect(find.text('Newest Career'), findsOneWidget);
    expect(find.text('Older Career'), findsOneWidget);
    expect(
      find.text('Other: New Other One (82%), New Other Two (76%)'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Newest Career')).dy,
      lessThan(tester.getTopLeft(find.text('Older Career')).dy),
    );
    expect(find.text('On device'), findsNWidgets(2));
    expect(find.text('View Matches'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy Matric history with old group and skill names opens', (
    tester,
  ) async {
    final legacyRecord = AssessmentRecord(
      id: 'legacy-matric',
      createdAt: DateTime(2025, 5, 6),
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
    AssessmentRecord? openedRecord;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HistoryScreen(
            repository: _MemoryHistoryRepository([legacyRecord]),
            onViewMatches: (record) => openedRecord = record,
            onStartAssessment: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Matric (Science Group (Biology, Chemistry, Physics))'),
      findsOneWidget,
    );
    await tester.tap(find.text('View Matches'));
    expect(openedRecord?.group, legacyRecord.group);
    expect(openedRecord?.skills, legacyRecord.skills);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy Bachelors TFLite and fallback records open', (
    tester,
  ) async {
    final records = [
      _record(
        id: 'legacy-tflite',
        createdAt: DateTime(2026, 11, 14),
        career: 'Legacy TFLite Career',
        percent: 84,
        engine: 'tflite',
        educationLevel: 'Bachelors',
        group: 'BS Software Engineering / Computer Science',
      ),
      _record(
        id: 'legacy-fallback',
        createdAt: DateTime(2026, 11, 13),
        career: 'Legacy Fallback Career',
        percent: 79,
        engine: 'fallback',
        educationLevel: 'Bachelors',
        group: 'BS Software Engineering / Computer Science',
      ),
    ];
    final openedEngines = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HistoryScreen(
            repository: _MemoryHistoryRepository(records),
            onViewMatches: (record) => openedEngines.add(record.engine),
            onStartAssessment: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewButtons = find.text('View Matches');
    await tester.tap(viewButtons.at(0));
    await tester.tap(viewButtons.at(1));
    expect(openedEngines, ['tflite', 'fallback']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear all is confirmed and can be canceled', (tester) async {
    final repository = _MemoryHistoryRepository([
      _record(
        id: 'only',
        createdAt: DateTime(2026, 11, 14),
        career: 'Career One',
        percent: 90,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HistoryScreen(
            repository: repository,
            onViewMatches: (_) {},
            onStartAssessment: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear assessment history?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.clearCount, 0);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(repository.clearCount, 1);
    expect(find.text('No assessments yet'), findsOneWidget);
  });

  test('share text includes the top three careers, percent, date, and app', () {
    final record = _record(
      id: 'shared',
      createdAt: DateTime(2026, 11, 14, 12, 41),
      career: 'Software Engineer',
      percent: 94,
      others: const [
        AssessmentCareerMatch(title: 'Data Analyst', matchPercent: 82),
        AssessmentCareerMatch(title: 'Cloud Architect', matchPercent: 76),
        AssessmentCareerMatch(title: 'Product Designer', matchPercent: 65),
      ],
    );

    expect(
      buildAssessmentShareText(record),
      'AI Career Advisor\n'
      'Top career: Software Engineer\n'
      'Match: 94%\n'
      'Top 3 matches:\n'
      'Software Engineer — 94%\n'
      'Data Analyst — 82%\n'
      'Cloud Architect — 76%\n'
      'Date: 14 Nov 2026 · 12:41 PM',
    );
  });
}

AssessmentRecord _record({
  required String id,
  required DateTime createdAt,
  required String career,
  required int percent,
  String engine = 'fallback',
  String educationLevel = 'Intermediate',
  String group = 'Pre-Engineering',
  List<AssessmentCareerMatch> others = const [],
}) {
  return AssessmentRecord(
    id: id,
    createdAt: createdAt,
    educationLevel: educationLevel,
    group: group,
    percentage: 84,
    riasecScores: const {'R': 3, 'I': 4},
    skills: const {'Communication': 4},
    top5: [
      AssessmentCareerMatch(title: career, matchPercent: percent),
      ...others,
    ],
    topCareer: career,
    engine: engine,
  );
}

class _MemoryHistoryRepository extends HistoryRepository {
  _MemoryHistoryRepository(List<AssessmentRecord> records)
    : _snapshot = AssessmentHistorySnapshot(
        records: records,
        isSignedIn: false,
        hasRemoteConnection: false,
        syncedIds: const {},
      ),
      super(authService: null);

  AssessmentHistorySnapshot _snapshot;
  int clearCount = 0;

  @override
  Future<AssessmentHistorySnapshot> loadWithStatus() async => _snapshot;

  @override
  Future<void> clearAll() async {
    clearCount++;
    _snapshot = _snapshot.withRecords(const []);
  }
}
