import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/alerts/domain/alerts_models.dart';
import 'package:student_mobile/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';

class _FakePastResults implements TestsGateway {
  _FakePastResults(this.snapshot);

  final PastResultsSnapshot snapshot;

  @override
  Future<PastResultsSnapshot> loadPastResults() async => snapshot;

  @override
  Future<TestsSnapshot> loadTests() async => const TestsSnapshot();

  @override
  Future<AssessmentDetailSnapshot> loadAssessmentDetail(
    AssessmentDetailArgs args,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<AssessmentAttemptSession> startAttempt(String assessmentId) async {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionSummary> finalizeSubmission(String submissionId) async {
    throw UnimplementedError();
  }

  @override
  Future<AttemptPlayerSnapshot> loadAttemptPlayer(
    AttemptPlayerArgs args,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSubmissionMetadata(
    String submissionId,
    Map<String, dynamic> metadata,
  ) async {}

  @override
  Future<SubmissionStatusPayload> getSubmissionStatus(
    String submissionId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ResultFeedbackSnapshot> loadResultFeedback(
    ResultFeedbackArgs args,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<DeepFeedbackSnapshot> loadDeepFeedback(DeepFeedbackArgs args) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FeedbackSuggestionItem>> listSuggestions(
    String evaluationId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FeedbackSuggestionItem>> generateSuggestions(
    String feedbackId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary> requestRewrite(
    String evaluationId,
    RewriteOptions options,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary?> getLatestRewrite(String evaluationId) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary> getRewriteRequest(
    String rewriteRequestId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteResultPayload?> getRewriteResult(
    String rewriteRequestId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary> processRewrite(String rewriteRequestId) async {
    throw UnimplementedError();
  }

  @override
  Future<AnswerImageAttachment> uploadAnswerImage({
    required String submissionId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required int pageNumber,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeAlerts implements AlertsGateway {
  _FakeAlerts(this.snapshot);

  AlertsSnapshot snapshot;
  final List<String> markedIds = [];
  int markAllCalls = 0;
  int? lastUnreadReported;

  @override
  Future<AlertsSnapshot> loadAlerts() async => snapshot;

  @override
  Future<int> unreadCount() async => snapshot.unreadCount;

  @override
  Future<void> markRead(AlertItem item) async {
    markedIds.add(item.id);
    snapshot = snapshot.markItemRead(item.id);
  }

  @override
  Future<void> markAllRead() async {
    markAllCalls += 1;
    snapshot = snapshot.markAllRead();
  }
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AlertsSnapshot sampleSnapshot({DateTime? now}) {
    final clock = now ?? DateTime.now();
    return AlertsSnapshot(
      unreadCount: 2,
      items: [
        AlertItem(
          id: 'n1',
          source: AlertSource.notification,
          title: 'Evaluation complete',
          body: 'Your Polity quiz feedback is ready.',
          category: AlertCategory.evaluation,
          eventType: 'evaluation.completed',
          submissionId: 'sub1',
          assessmentId: 'a1',
          isRead: false,
          createdAt: clock,
        ),
        AlertItem(
          id: 'i1',
          source: AlertSource.inbox,
          title: 'Academy announcement',
          body: 'Live class moved to 6 PM.',
          category: AlertCategory.messages,
          isRead: false,
          createdAt: clock.subtract(const Duration(days: 1)),
        ),
        AlertItem(
          id: 'n2',
          source: AlertSource.notification,
          title: 'Lesson published',
          body: 'Module 3 notes are live.',
          category: AlertCategory.learning,
          eventType: 'learning.lesson_published',
          lessonId: 'lesson1',
          courseId: 'course1',
          isRead: true,
          createdAt: clock.subtract(const Duration(days: 3)),
        ),
      ],
    );
  }

  testWidgets('S-50 lists alerts by day and marks one read', (tester) async {
    final fake = _FakeAlerts(sampleSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AlertsScreen(
          alertsRepository: fake,
          onUnreadChanged: (count) => fake.lastUnreadReported = count,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('S-50 is next'), findsNothing);
    expect(find.text('2 unread · grouped by day'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Evaluation complete'), findsOneWidget);
    expect(find.text('Evaluation'), findsWidgets);
    expect(find.text('Academy announcement'), findsOneWidget);
    expect(find.text('Open result'), findsOneWidget);

    await tester.tap(find.text('Mark read').first);
    await tester.pumpAndSettle();

    expect(fake.markedIds, contains('n1'));
    expect(fake.lastUnreadReported, 1);
    expect(find.text('1 unread · grouped by day'), findsOneWidget);
  });

  testWidgets('S-50 mark all read clears unread', (tester) async {
    final fake = _FakeAlerts(sampleSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AlertsScreen(alertsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(fake.markAllCalls, 1);
    expect(find.text('All caught up · grouped by day'), findsOneWidget);
    expect(find.text('Unread'), findsNothing);
  });

  testWidgets('S-50 empty state', (tester) async {
    final fake = _FakeAlerts(const AlertsSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AlertsScreen(alertsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('AI Eval tab shows hub in shell', (tester) async {
    final fakeTests = _FakePastResults(
      PastResultsSnapshot(
        submissions: const [
          SubmissionSummary(
            id: 'sub1',
            assessmentId: 'a1',
            attemptNumber: 1,
            status: 'evaluated',
            totalScore: 14,
            maxScore: 20,
            percentage: 70,
          ),
        ],
        assessmentTitles: const {'a1': 'Polity Weekly Quiz'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(
          initialIndex: 3,
          homeRepository: _FakeHome(),
          testsRepository: fakeTests,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Eval'), findsWidgets);
    expect(find.text('AI Evaluation'), findsOneWidget);
    expect(find.text('Polity Weekly Quiz'), findsOneWidget);
    expect(find.text('Evaluation complete'), findsNothing);
  });

  testWidgets('S-50 Alerts opens via named route', (tester) async {
    final fake = _FakeAlerts(sampleSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlertsScreen(alertsRepository: fake),
                  ),
                );
              },
              child: const Text('Open alerts'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Evaluation complete'), findsOneWidget);
  });

  testWidgets('S-51 tap opens linked result screen', (tester) async {
    Object? pushedArgs;
    String? pushedRoute;
    final fake = _FakeAlerts(sampleSnapshot());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AlertsScreen(alertsRepository: fake),
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          pushedArgs = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(
              body: Text('Result destination'),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Evaluation complete'));
    await tester.pumpAndSettle();

    expect(fake.markedIds, contains('n1'));
    expect(pushedRoute, '/result-feedback');
    expect(pushedArgs, isA<ResultFeedbackArgs>());
    expect((pushedArgs! as ResultFeedbackArgs).submissionId, 'sub1');
    expect(find.text('Result destination'), findsOneWidget);
  });
}
