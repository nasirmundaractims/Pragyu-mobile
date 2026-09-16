import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/weak_topics/data/weak_topics_repository.dart';
import 'package:student_mobile/features/weak_topics/domain/weak_topics_models.dart';
import 'package:student_mobile/features/weak_topics/presentation/screens/weak_topics_screen.dart';

class _FakeWeakTopics implements WeakTopicsGateway {
  _FakeWeakTopics(this.snapshot);

  final WeakTopicsSnapshot snapshot;

  @override
  Future<WeakTopicsSnapshot> loadWeakTopics() async => snapshot;
}

void main() {
  testWidgets('S-61 shows focus list and metrics', (tester) async {
    final fake = _FakeWeakTopics(
      WeakTopicsSnapshot(
        studentProfileId: 'sp-1',
        topics: const [
          WeakTopicItem(
            id: 'w1',
            name: 'polity/federalism',
            mastery: 32,
            status: TopicMasteryStatus.weak,
            difficulty: 'Hard',
            attempts: 3,
          ),
          WeakTopicItem(
            id: 'i1',
            name: 'economy/inflation',
            mastery: 58,
            status: TopicMasteryStatus.improving,
            attempts: 5,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: WeakTopicsScreen(weakTopicsRepository: fake),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.aiMentor) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                body: Text('Mentor stub'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focus where it matters most'), findsOneWidget);
    expect(find.text('polity/federalism'), findsOneWidget);
    expect(find.text('economy/inflation'), findsOneWidget);
    expect(find.text('Needs work'), findsWidgets);
    expect(find.text('Improving'), findsWidgets);
    expect(find.text('Ask Mentor'), findsWidgets);

    await tester.tap(find.text('Ask Mentor').first);
    await tester.pumpAndSettle();
    expect(find.text('Mentor stub'), findsOneWidget);
  });

  testWidgets('S-61 empty state when no focus topics', (tester) async {
    final fake = _FakeWeakTopics(
      const WeakTopicsSnapshot(studentProfileId: 'sp-1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: WeakTopicsScreen(weakTopicsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No weak topics right now'), findsOneWidget);
  });
}
