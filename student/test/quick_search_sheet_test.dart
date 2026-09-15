import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/search/data/search_repository.dart';
import 'package:student_mobile/features/search/domain/search_models.dart';
import 'package:student_mobile/features/search/presentation/widgets/quick_search_sheet.dart';

class _FakeHome implements HomeGateway {
  @override
  Future<HomeSnapshot> loadHome() async {
    return const HomeSnapshot(
      user: AuthUser(id: '1', email: 'a@b.com', firstName: 'Alex'),
    );
  }

  @override
  Future<TodaySnapshot> loadToday() async {
    return TodaySnapshot(day: DateTime(2026, 9, 15));
  }
}

class _FakeSearch implements SearchGateway {
  @override
  Future<QuickSearchCatalog> loadCatalog() async {
    return const QuickSearchCatalog(
      courses: [
        SearchHit(
          id: 'c1',
          title: 'UPSC GS Foundation',
          kind: SearchHitKind.course,
          subtitle: 'Batch A',
        ),
      ],
      tests: [
        SearchHit(
          id: 't1',
          title: 'Weekly Polity Quiz',
          kind: SearchHitKind.test,
          subtitle: 'quiz',
        ),
      ],
    );
  }

  @override
  Future<List<SearchHit>> searchMaterials(String query) async {
    if (!query.toLowerCase().contains('const')) return const [];
    return const [
      SearchHit(
        id: 'm1',
        title: 'Constitution Basics',
        kind: SearchHitKind.material,
        materialType: 'lesson',
      ),
    ];
  }

  @override
  QuickSearchResults filterCatalog(QuickSearchCatalog catalog, String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const QuickSearchResults();
    return QuickSearchResults(
      courses: catalog.courses
          .where((h) => h.title.toLowerCase().contains(q))
          .toList(),
      tests: catalog.tests
          .where((h) => h.title.toLowerCase().contains(q))
          .toList(),
    );
  }
}

/// Advance past catalog load + sheet open without waiting on cursor blink /
/// indeterminate progress (which never settle).
Future<void> _pumpSheetReady(WidgetTester tester) async {
  await tester.pump(); // open sheet
  await tester.pump(); // post-frame focus + start catalog
  await tester.pump(const Duration(milliseconds: 50)); // catalog Future
}

Future<void> _pumpAfterQuery(WidgetTester tester) async {
  await tester.pump(); // onChanged / local filter
  await tester.pump(const Duration(milliseconds: 300)); // debounce
  await tester.pump(); // materials Future start
  await tester.pump(const Duration(milliseconds: 50)); // materials done
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-12 quick search finds course and test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(homeRepository: _FakeHome()),
      ),
    );
    await tester.pumpAndSettle();

    // Do not await — Future completes only when the sheet is dismissed.
    showQuickSearchSheet(
      tester.element(find.byType(StudentShell)),
      searchRepository: _FakeSearch(),
    );
    await _pumpSheetReady(tester);

    expect(find.text('Quick search'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pol');
    await _pumpAfterQuery(tester);

    expect(find.text('Weekly Polity Quiz'), findsOneWidget);
  });

  testWidgets('S-12 searches materials after debounce', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showQuickSearchSheet(
                      context,
                      searchRepository: _FakeSearch(),
                    );
                  },
                  child: const Text('Open search'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open search'));
    await _pumpSheetReady(tester);

    await tester.enterText(find.byType(TextField), 'const');
    await _pumpAfterQuery(tester);

    expect(find.text('Constitution Basics'), findsOneWidget);
    expect(find.text('Materials'), findsOneWidget);
  });
}
