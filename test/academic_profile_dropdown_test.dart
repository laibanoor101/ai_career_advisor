import 'package:ai_career_advisor/screens/academic_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bachelors selects CGPA and clears the previous percentage', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AcademicProfileScreen()));
    await tester.pumpAndSettle();

    final scoreField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    expect(scoreField.controller?.text, '84.5');

    await tester.tap(find.text('Bachelors').first);
    await tester.pumpAndSettle();

    final updatedScoreField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    expect(updatedScoreField.controller?.text, isEmpty);
    expect(
      tester
          .widget<InputDecorator>(find.byType(InputDecorator).last)
          .decoration
          .suffixText,
      '/ 4.0',
    );
  });

  testWidgets('Bachelors rejects Percentage and shows the themed SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AcademicProfileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bachelors').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Percentage %'));
    await tester.pump();
    expect(
      find.text('For Bachelors, please enter CGPA only (out of 4.0).'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<InputDecorator>(find.byType(InputDecorator).last)
          .decoration
          .suffixText,
      '/ 4.0',
    );
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.duration, const Duration(seconds: 3));
  });

  testWidgets('Matric and Intermediate still allow Percentage', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AcademicProfileScreen()));
    await tester.pumpAndSettle();

    for (final level in ['Matric', 'Intermediate']) {
      await tester.tap(find.text(level).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Percentage %'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<InputDecorator>(find.byType(InputDecorator).last)
            .decoration
            .suffixText,
        '%',
      );
      final scoreField = tester.widget<TextFormField>(
        find.byType(TextFormField).last,
      );
      expect(scoreField.controller?.text, '84.5');
    }
  });

  testWidgets(
    'education changes reset specialization to one valid unique option',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AcademicProfileScreen()));
      await tester.pumpAndSettle();

      void expectValidDropdown() {
        final dropdown = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        );
        final values = dropdown.items!.map((item) => item.value).toList();

        expect(values.toSet(), hasLength(values.length));
        expect(dropdown.value, isNotNull);
        expect(values.where((value) => value == dropdown.value), hasLength(1));
      }

      expectValidDropdown();

      await tester.tap(find.text('Matric').first);
      await tester.pumpAndSettle();
      expectValidDropdown();
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .items!
            .map((item) => item.value)
            .toList(),
        [
          'Science Group (Bio-Science)',
          'General Science Group (Computer Science)',
          'Arts / Humanities & Home Economics Group',
        ],
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Bachelors').first);
      await tester.pumpAndSettle();
      expectValidDropdown();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Intermediate').first);
      await tester.pumpAndSettle();
      expectValidDropdown();
      expect(tester.takeException(), isNull);
    },
  );
}
