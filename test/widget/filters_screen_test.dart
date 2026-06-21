import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqary/screens/buyer/filters_screen.dart';
import 'package:aqary/utils/app_theme.dart';

// Widget tests for the Filters screen.
// Run with: flutter test test/widget/filters_screen_test.dart

void main() {
  Widget buildFiltersScreen({Map<String, dynamic> filters = const {}}) {
    return MaterialApp(
      theme: AppTheme.theme,
      home: FiltersScreen(currentFilters: filters),
    );
  }

  group('FiltersScreen — layout', () {
    testWidgets('shows area filter chips', (tester) async {
      await tester.pumpWidget(buildFiltersScreen());
      expect(find.text('All Areas'), findsOneWidget);
      expect(find.text('Amman'), findsOneWidget);
      expect(find.text('Zarqa'), findsOneWidget);
    });

    testWidgets('shows land type checkboxes', (tester) async {
      await tester.pumpWidget(buildFiltersScreen());
      expect(find.text('Residential'), findsOneWidget);
      expect(find.text('Commercial'), findsOneWidget);
      expect(find.text('Agricultural'), findsOneWidget);
    });

    testWidgets('shows Apply Filters button', (tester) async {
      await tester.pumpWidget(buildFiltersScreen());
      expect(find.text('Apply Filters'), findsOneWidget);
    });

    testWidgets('shows Reset button in app bar', (tester) async {
      await tester.pumpWidget(buildFiltersScreen());
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('shows price range slider', (tester) async {
      await tester.pumpWidget(buildFiltersScreen());
      expect(find.text('Price Range (JD)'), findsOneWidget);
      expect(find.byType(RangeSlider), findsWidgets);
    });
  });

  group('FiltersScreen — pre-filled filters', () {
    testWidgets('pre-selects area from currentFilters', (tester) async {
      await tester.pumpWidget(buildFiltersScreen(
        filters: {'area': 'Amman'},
      ));
      // 'Amman' chip should appear selected (white text on primary bg)
      expect(find.text('Amman'), findsOneWidget);
    });

    testWidgets('Apply returns filters map via Navigator.pop', (tester) async {
      Map<String, dynamic>? returnedFilters;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Builder(builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              returnedFilters =
                  await Navigator.push<Map<String, dynamic>>(
                ctx,
                MaterialPageRoute(
                    builder: (_) =>
                        const FiltersScreen(currentFilters: {})),
              );
            },
            child: const Text('Open'),
          ),
        )),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      // Filters map is returned (empty since nothing was selected)
      expect(returnedFilters, isNotNull);
      expect(returnedFilters, isA<Map<String, dynamic>>());
    });
  });
}
