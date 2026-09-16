import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/recommendations/data/recommendations_repository.dart';
import 'package:student_mobile/features/recommendations/domain/recommendations_models.dart';
import 'package:student_mobile/features/recommendations/presentation/screens/recommendations_screen.dart';

class _FakeRecommendations implements RecommendationsGateway {
  _FakeRecommendations(this.snapshot);

  RecommendationsSnapshot snapshot;
  int generateCalls = 0;
  final outcomes = <String, String>{};

  @override
  Future<RecommendationsSnapshot> loadRecommendations() async => snapshot;

  @override
  Future<List<RecommendationItem>> generateRecommendations({
    required String studentProfileId,
  }) async {
    generateCalls += 1;
    const items = [
      RecommendationItem(
        id: 'gen-1',
        title: 'Fresh recommendation',
        reason: 'Generated from signals',
        estimatedMinutes: 20,
        priority: RecommendationPriority.high,
        groups: [RecommendationGroup.today],
      ),
    ];
    snapshot = snapshot.copyWith(items: items);
    return items;
  }

  @override
  Future<void> recordOutcome({
    required String recommendationId,
    required String outcome,
  }) async {
    outcomes[recommendationId] = outcome;
  }
}

void main() {
  testWidgets('S-63 lists recommendations and dismisses one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeRecommendations(
      const RecommendationsSnapshot(
        studentProfileId: 'sp-1',
        weakTopicCount: 2,
        items: [
          RecommendationItem(
            id: 'r1',
            title: 'Practice Federalism',
            reason: 'Mastery is still low.',
            estimatedMinutes: 25,
            priority: RecommendationPriority.high,
            difficulty: 'Focused',
            whenLabel: 'Today',
            groups: [RecommendationGroup.today, RecommendationGroup.weakTopics],
            actions: [
              RecommendationAction(
                type: 'start_revision',
                label: 'Start revision',
              ),
            ],
          ),
          RecommendationItem(
            id: 'r2',
            title: 'Ask Mentor about DPSP',
            reason: 'Get a clear explanation.',
            estimatedMinutes: 15,
            priority: RecommendationPriority.medium,
            groups: [RecommendationGroup.thisWeek],
            actions: [
              RecommendationAction(
                type: 'ask_ai_coach',
                label: 'Ask Mentor',
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RecommendationsScreen(recommendationsRepository: fake),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.weakTopics) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Weak topics stub')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI recommendations for you'), findsOneWidget);
    expect(find.text('Practice Federalism'), findsOneWidget);
    expect(find.text('Ask Mentor about DPSP'), findsOneWidget);

    await tester.ensureVisible(find.text('Dismiss').first);
    await tester.tap(find.text('Dismiss').first);
    await tester.pumpAndSettle();

    expect(find.text('Practice Federalism'), findsNothing);
    expect(fake.outcomes['r1'], 'dismissed');
    expect(find.text('Ask Mentor'), findsWidgets);
  });

  testWidgets('S-63 empty state generates recommendations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeRecommendations(
      const RecommendationsSnapshot(studentProfileId: 'sp-1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RecommendationsScreen(recommendationsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No recommendations right now'), findsOneWidget);

    await tester.ensureVisible(find.text('Generate recommendations'));
    await tester.tap(find.text('Generate recommendations'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fake.generateCalls, 1);
    expect(find.text('Fresh recommendation'), findsOneWidget);
  });
}
