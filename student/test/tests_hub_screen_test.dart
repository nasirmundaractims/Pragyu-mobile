import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/tests_hub_screen.dart';

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

class _FakeTests implements TestsGateway {
  _FakeTests(this.snapshot);

  final TestsSnapshot snapshot;

  @override
  Future<TestsSnapshot> loadTests() async => snapshot;

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
  Future<List<FeedbackSuggestionItem>> listSuggestions(String evaluationId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FeedbackSuggestionItem>> generateSuggestions(String feedbackId) async {
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
  Future<RewriteRequestSummary> getRewriteRequest(String rewriteRequestId) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteResultPayload?> getRewriteResult(String rewriteRequestId) async {
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

  @override
  Future<PastResultsSnapshot> loadPastResults() async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-40 lists published tests with type and due', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TestsHubScreen(
          testsRepository: _FakeTests(
            TestsSnapshot(
              items: [
                TestListItem(
                  id: 'a1',
                  title: 'Polity Weekly Quiz',
                  type: TestKind.quiz,
                  durationMinutes: 30,
                  totalMarks: 50,
                  questionsCount: 25,
                  due: const DueState(
                    urgency: DueUrgency.dueToday,
                    label: 'Due today',
                  ),
                ),
                const TestListItem(
                  id: 'a2',
                  title: 'GS Mock Exam',
                  type: TestKind.exam,
                  durationMinutes: 120,
                  totalMarks: 200,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice'), findsWidgets);
    expect(find.text('Polity Weekly Quiz'), findsWidgets);
    expect(find.text('Due today'), findsWidgets);
    expect(find.textContaining('Quiz'), findsWidgets);
    expect(find.text('GS Mock Exam'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Due soon'), findsOneWidget);
  });

  testWidgets('S-40 empty assigned list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TestsHubScreen(
          testsRepository: _FakeTests(const TestsSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tests assigned yet.'), findsOneWidget);
  });

  testWidgets('S-40 Tests tab shows hub', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(
          initialIndex: 2,
          homeRepository: _FakeHome(),
          testsRepository: _FakeTests(
            const TestsSnapshot(
              items: [
                TestListItem(
                  id: 'a1',
                  title: 'Current Affairs Drill',
                  type: TestKind.practice,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice'), findsWidgets);
    expect(find.text('Current Affairs Drill'), findsWidgets);
    expect(find.text('S-40 is next'), findsNothing);
  });

  testWidgets('S-40 filter Due soon and row opens S-41', (tester) async {
    Object? pushedArgs;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TestsHubScreen(
          testsRepository: _FakeTests(
            TestsSnapshot(
              items: [
                TestListItem(
                  id: 'a1',
                  title: 'Due Quiz',
                  type: TestKind.quiz,
                  due: const DueState(
                    urgency: DueUrgency.dueToday,
                    label: 'Due today',
                  ),
                ),
                const TestListItem(
                  id: 'a2',
                  title: 'Later Exam',
                  type: TestKind.exam,
                ),
              ],
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.assessmentDetail) {
            pushedArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Assessment detail')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Due soon'));
    await tester.pumpAndSettle();

    expect(find.text('Due Quiz'), findsWidgets);
    expect(find.text('Later Exam'), findsNothing);

    await tester.ensureVisible(find.text('Due Quiz').first);
    await tester.tap(find.text('Due Quiz').first);
    await tester.pumpAndSettle();
    // Topic card selects; open via Start / Submit Test CTA.
    await tester.ensureVisible(find.text('Submit Test'));
    await tester.tap(find.text('Submit Test'));
    await tester.pumpAndSettle();

    expect(find.text('Assessment detail'), findsOneWidget);
    expect(pushedArgs, isA<AssessmentDetailArgs>());
    expect((pushedArgs! as AssessmentDetailArgs).assessmentId, 'a1');
  });

  testWidgets('S-40 Practice layout has no overflow at phone sizes', (tester) async {
    final sizes = <Size>[
      const Size(320, 568),
      const Size(360, 640),
      const Size(390, 844),
      const Size(430, 932),
    ];
    final overflows = <String>[];

    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);

      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.exceptionAsString();
        if (message.contains('overflowed')) {
          overflows.add('${size.width.toInt()}x${size.height.toInt()}: $message');
        }
        previousOnError?.call(details);
      };

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TestsHubScreen(
            testsRepository: _FakeTests(
              TestsSnapshot(
                items: [
                  TestListItem(
                    id: 'a1',
                    title: 'Polity Weekly Quiz',
                    type: TestKind.quiz,
                    durationMinutes: 30,
                    totalMarks: 50,
                    questionsCount: 25,
                    due: const DueState(
                      urgency: DueUrgency.dueToday,
                      label: 'Due today',
                    ),
                  ),
                  const TestListItem(
                    id: 'a2',
                    title: 'GS Mock Exam',
                    type: TestKind.exam,
                    durationMinutes: 120,
                    totalMarks: 200,
                    questionsCount: 100,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Allow async load + first frame; avoid hanging on asset/image tickers.
      var found = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Practice').evaluate().isNotEmpty) {
          found = true;
          break;
        }
      }
      expect(
        found,
        isTrue,
        reason: 'Practice hero missing at ${size.width}x${size.height}',
      );

      if (find.byType(RefreshIndicator).evaluate().isNotEmpty) {
        await tester.drag(
          find.byType(RefreshIndicator),
          const Offset(0, -600),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      FlutterError.onError = previousOnError;
    }

    await tester.binding.setSurfaceSize(null);
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });
}