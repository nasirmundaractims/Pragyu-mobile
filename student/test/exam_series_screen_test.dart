import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/exam_series/data/exam_series_repository.dart';
import 'package:student_mobile/features/exam_series/domain/exam_series_models.dart';
import 'package:student_mobile/features/exam_series/presentation/screens/exam_series_detail_screen.dart';
import 'package:student_mobile/features/exam_series/presentation/screens/exam_series_screen.dart';

class _FakeSeries implements ExamSeriesGateway {
  _FakeSeries({
    required this.hub,
    this.detail,
  });

  final ExamSeriesHubSnapshot hub;
  final ExamSeriesDetailSnapshot? detail;
  ExamSeriesPack? ensured;

  @override
  Future<ExamSeriesHubSnapshot> loadHub() async => hub;

  @override
  Future<ExamSeriesDetailSnapshot> loadDetail(ExamSeriesDetailArgs args) async {
    return detail ??
        ExamSeriesDetailSnapshot(
          pack: ExamSeriesPack(
            id: args.seriesId,
            title: args.title ?? 'Pack',
            items: const [],
          ),
        );
  }

  @override
  Future<void> ensureSellerWorkspace(ExamSeriesPack pack) async {
    ensured = pack;
  }
}

void main() {
  testWidgets('S-67 hub lists packs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeSeries(
      hub: const ExamSeriesHubSnapshot(
        activeOrganizationId: 'org-1',
        packs: [
          ExamSeriesPack(
            id: 'es-1',
            title: 'GPSC Full Pack',
            description: 'Mocks and PYQs',
            itemCount: 4,
            organizationId: 'org-1',
            organizationName: 'Pragyu Academy',
            workspaceOrganizationId: 'org-1',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ExamSeriesScreen(seriesRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 exam series pack'), findsOneWidget);
    expect(find.text('GPSC Full Pack'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Exam Workspace'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
  });

  testWidgets('S-67 empty hub shows browse CTAs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ExamSeriesScreen(
          seriesRepository: _FakeSeries(hub: const ExamSeriesHubSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your exam series hub'), findsOneWidget);
    expect(find.text('Browse individual tests'), findsOneWidget);
    expect(find.text('Open Exam Workspace'), findsOneWidget);
  });

  testWidgets('S-67 workspace opens nested from series hub', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ExamSeriesScreen(
          seriesRepository: _FakeSeries(
            hub: const ExamSeriesHubSnapshot(
              packs: [
                ExamSeriesPack(
                  id: 'es-1',
                  title: 'GPSC Full Pack',
                  itemCount: 2,
                ),
              ],
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.examWorkspace) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Exam Workspace page')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exam Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Exam Workspace page'), findsOneWidget);
  });

  testWidgets('S-67 detail shows rank and take test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final detail = ExamSeriesDetailSnapshot(
      pack: const ExamSeriesPack(
        id: 'es-1',
        title: 'GPSC Full Pack',
        description: 'Focused CBRT pack',
        organizationName: 'Pragyu Academy',
        items: [
          ExamSeriesItem(
            id: 'i1',
            assessmentId: 'a1',
            assessmentTitle: 'Mock Test 1',
            itemType: 'mock',
          ),
        ],
      ),
      rank: const ExamSeriesRank(
        disclosed: true,
        rank: 3,
        totalMarks: 210,
        cohortSize: 50,
        assessmentsScored: 2,
        assessmentsInSeries: 4,
        assessmentsDisclosed: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ExamSeriesDetailScreen(
          args: const ExamSeriesDetailArgs(
            seriesId: 'es-1',
            title: 'GPSC Full Pack',
          ),
          seriesRepository: _FakeSeries(
            hub: const ExamSeriesHubSnapshot(),
            detail: detail,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPSC Full Pack'), findsWidgets);
    expect(find.text('Your series rank'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Mock Test 1'), findsOneWidget);
    expect(find.text('Take test'), findsOneWidget);
  });
}
