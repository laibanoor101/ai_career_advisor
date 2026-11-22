import 'package:ai_career_advisor/constants/app_theme.dart';
import 'package:ai_career_advisor/screens/academic_profile_screen.dart';
import 'package:ai_career_advisor/services/history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('History shortcut is visible in both themes', (tester) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: AcademicProfileScreen(
            historyRepository: _MemoryHistoryRepository(const []),
          ),
        ),
      );

      expect(find.byTooltip('History'), findsOneWidget);
      expect(
        find.widgetWithIcon(IconButton, Icons.history_rounded),
        findsOneWidget,
      );
    }
  });

  testWidgets('narrow headers keep the pill and History button usable', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 360.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: AcademicProfileScreen(
              historyRepository: _MemoryHistoryRepository(const []),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pillFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Step 1 of 3: Academics' ||
                  widget.data == 'Step 1 of 3'),
        );
        expect(pillFinder, findsOneWidget);
        final pillText = tester.widget<Text>(pillFinder);
        expect(
          pillText.data,
          width == 320 ? 'Step 1 of 3' : 'Step 1 of 3: Academics',
        );
        expect(pillText.maxLines, 1);
        expect(pillText.softWrap, isFalse);

        final header = tester.renderObject<RenderFlex>(
          find.byKey(const ValueKey('academic-profile-header')),
        );
        var child = header.firstChild;
        while (child != null) {
          final childRight =
              (child.parentData! as FlexParentData).offset.dx +
              child.size.width;
          expect(childRight, lessThanOrEqualTo(header.size.width));
          child = header.childAfter(child);
        }

        final screenException = tester.takeException();
        // The separate Educational Milestones banner overflows at 320 px.
        if (width == 360) {
          expect(screenException, isNull);
        }

        final historyButton = find.widgetWithIcon(
          IconButton,
          Icons.history_rounded,
        );
        expect(historyButton, findsOneWidget);
        final buttonSize = tester.getSize(historyButton);
        expect(buttonSize.width, greaterThanOrEqualTo(40));
        expect(buttonSize.height, greaterThanOrEqualTo(40));
        await tester.tap(find.byTooltip('History'));
        await tester.pumpAndSettle();
        expect(find.text('Assessment History'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('History shortcut opens the History screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AcademicProfileScreen(
          historyRepository: _MemoryHistoryRepository(const []),
        ),
      ),
    );

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    expect(find.text('Assessment History'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('empty History can return to Academic Profile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: AcademicProfileScreen(
          historyRepository: _MemoryHistoryRepository(const []),
        ),
      ),
    );
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    expect(find.text('No assessments yet'), findsOneWidget);
    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Your Academic Profile'), findsOneWidget);
    expect(find.text('Assessment History'), findsNothing);
  });

  testWidgets('saved history matches open and return through both screens', (
    tester,
  ) async {
    final record = AssessmentRecord(
      id: 'saved-record',
      createdAt: DateTime(2026, 11, 14, 12, 41),
      educationLevel: 'Intermediate',
      group: 'Pre-Engineering',
      percentage: 88,
      riasecScores: const {'R': 3, 'I': 4},
      skills: const {'Communication': 4},
      top5: const [
        AssessmentCareerMatch(title: 'Software Engineer', matchPercent: 92),
      ],
      topCareer: 'Software Engineer',
      engine: 'test',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AcademicProfileScreen(
          historyRepository: _MemoryHistoryRepository([record]),
        ),
      ),
    );
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    expect(find.text('Software Engineer'), findsOneWidget);
    await tester.tap(find.text('View Matches'));
    await tester.pumpAndSettle();

    expect(find.text('Top Career Matches'), findsOneWidget);
    expect(find.text('Software Engineer'), findsNWidgets(2));
    expect(find.text('92%'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Assessment History'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Your Academic Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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

  final AssessmentHistorySnapshot _snapshot;

  @override
  Future<AssessmentHistorySnapshot> loadWithStatus() async => _snapshot;
}