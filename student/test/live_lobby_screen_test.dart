import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/lectures/presentation/screens/live_lobby_screen.dart';
import 'package:student_mobile/features/lectures/presentation/screens/live_room_screen.dart';

class _FakeLectures implements LecturesGateway {
  _FakeLectures({
    required this.lobby,
    this.joinResult = const LiveJoinResult(inWaitingRoom: true),
  });

  LiveLobbySnapshot lobby;
  final LiveJoinResult joinResult;
  bool joinCalled = false;

  @override
  Future<LecturesSnapshot> loadLectures({String? courseId}) async {
    return const LecturesSnapshot();
  }

  @override
  Future<LiveLobbySnapshot> loadLiveLobby(String lectureId) async => lobby;

  @override
  Future<LiveJoinResult> joinLive(String lectureId) async {
    joinCalled = true;
    return joinResult;
  }

  @override
  Future<List<LiveChatMessage>> listLiveChat(String lectureId) async {
    return const [
      LiveChatMessage(
        id: 'c1',
        body: 'Welcome to class',
        authorRole: 'faculty',
      ),
    ];
  }

  @override
  Future<LiveChatMessage> postLiveChat(String lectureId, String body) async {
    return LiveChatMessage(id: 'c2', body: body);
  }

  @override
  Future<void> sendAttendanceHeartbeat(String lectureId) async {}

  @override
  Future<RecordedLectureSnapshot> loadRecordedLecture(String lectureId) async {
    return RecordedLectureSnapshot(
      lectureId: lectureId,
      title: 'Recording',
      hasVideo: true,
    );
  }

  @override
  Future<LecturePlaybackInfo> loadPlayback(String lectureId) async {
    return const LecturePlaybackInfo();
  }

  @override
  Future<RecordedLectureSnapshot> completeRecordedLecture(
    String lectureId,
  ) async {
    return RecordedLectureSnapshot(
      lectureId: lectureId,
      title: 'Recording',
      isCompleted: true,
      progressPercent: 100,
    );
  }

  @override
  Future<void> reportPlaybackProgress({
    required String lectureId,
    required int positionSeconds,
    int? deltaSeconds,
    int? progressPercent,
  }) async {}

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-24 shows waiting lobby and check-in', (tester) async {
    final fake = _FakeLectures(
      lobby: LiveLobbySnapshot(
        lectureId: 'lec-1',
        title: 'Live Polity Doubt Session',
        subjectName: 'Polity',
        courseName: 'UPSC GS',
        startsAt: DateTime(2026, 9, 15, 18),
        sessionStatus: LiveSessionStatus.waiting,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LiveLobbyScreen(
          args: const LiveLobbyArgs(
            lectureId: 'lec-1',
            title: 'Live Polity Doubt Session',
          ),
          lecturesRepository: fake,
          pollInterval: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live lobby'), findsOneWidget);
    expect(find.text('Live Polity Doubt Session'), findsOneWidget);
    expect(find.text('Check-in open'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Polity · UPSC GS'), findsOneWidget);

    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();

    expect(fake.joinCalled, isTrue);
    expect(find.textContaining('Checked in'), findsWidgets);
  });

  testWidgets('S-24 join live opens S-25', (tester) async {
    final fake = _FakeLectures(
      lobby: const LiveLobbySnapshot(
        lectureId: 'lec-2',
        title: 'Evening Class',
        sessionStatus: LiveSessionStatus.live,
      ),
      joinResult: const LiveJoinResult(
        inWaitingRoom: false,
        hasMediaToken: true,
        sessionStatus: LiveSessionStatus.live,
        mediaUrl: 'https://example.test/room',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.liveRoom) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => LiveRoomScreen(
                args: LiveRoomArgs.fromObject(settings.arguments),
                lecturesRepository: fake,
                chatPollInterval: null,
                heartbeatInterval: null,
              ),
            );
          }
          return onGenerateRoute(settings);
        },
        home: LiveLobbyScreen(
          args: const LiveLobbyArgs(lectureId: 'lec-2', title: 'Evening Class'),
          lecturesRepository: fake,
          pollInterval: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Join class'), findsOneWidget);

    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();

    expect(fake.joinCalled, isTrue);
    expect(find.text('Live room'), findsOneWidget);
    expect(find.text('Welcome to class'), findsOneWidget);
  });

  testWidgets('S-24 ended disables action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LiveLobbyScreen(
          args: const LiveLobbyArgs(lectureId: 'lec-3'),
          lecturesRepository: _FakeLectures(
            lobby: const LiveLobbySnapshot(
              lectureId: 'lec-3',
              title: 'Past Class',
              sessionStatus: LiveSessionStatus.ended,
            ),
          ),
          pollInterval: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ended'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  test('countdownLabel formats near start', () {
    final snapshot = LiveLobbySnapshot(
      lectureId: '1',
      title: 'Class',
      startsAt: DateTime(2026, 9, 15, 12, 20),
      sessionStatus: LiveSessionStatus.scheduled,
    );
    expect(
      snapshot.countdownLabel(now: DateTime(2026, 9, 15, 12, 5)),
      'Starts in 15 min',
    );
  });
}
