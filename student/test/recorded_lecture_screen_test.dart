import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/lectures/presentation/screens/recorded_lecture_screen.dart';

class _FakeLectures implements LecturesGateway {
  _FakeLectures({required this.snapshot});

  RecordedLectureSnapshot snapshot;
  final LecturePlaybackInfo playback = const LecturePlaybackInfo(
    playbackUrl: 'https://cdn.example.test/lecture.m3u8',
    qualities: ['720p', '1080p'],
    playbackSpeeds: [1.0, 1.5, 2.0],
  );
  bool completeCalled = false;
  bool playbackCalled = false;

  @override
  Future<LecturesSnapshot> loadLectures({String? courseId}) async {
    return const LecturesSnapshot();
  }

  @override
  Future<LiveLobbySnapshot> loadLiveLobby(String lectureId) async {
    return LiveLobbySnapshot(
      lectureId: lectureId,
      title: 'Lobby',
      sessionStatus: LiveSessionStatus.scheduled,
    );
  }

  @override
  Future<LiveJoinResult> joinLive(String lectureId) async {
    return const LiveJoinResult(inWaitingRoom: true);
  }

  @override
  Future<List<LiveChatMessage>> listLiveChat(String lectureId) async {
    return const [];
  }

  @override
  Future<LiveChatMessage> postLiveChat(String lectureId, String body) async {
    return LiveChatMessage(id: '1', body: body);
  }

  @override
  Future<void> sendAttendanceHeartbeat(String lectureId) async {}

  @override
  Future<RecordedLectureSnapshot> loadRecordedLecture(String lectureId) async {
    return snapshot;
  }

  @override
  Future<LecturePlaybackInfo> loadPlayback(String lectureId) async {
    playbackCalled = true;
    return playback;
  }

  @override
  Future<RecordedLectureSnapshot> completeRecordedLecture(
    String lectureId,
  ) async {
    completeCalled = true;
    snapshot = snapshot.copyWith(
      isCompleted: true,
      progressPercent: 100,
    );
    return snapshot;
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

  testWidgets('S-26 shows progress and loads playback link', (tester) async {
    final fake = _FakeLectures(
      snapshot: const RecordedLectureSnapshot(
        lectureId: 'lec-1',
        title: 'Constitution Recording',
        subjectName: 'Polity',
        courseName: 'UPSC GS',
        durationSeconds: 1800,
        progressPercent: 40,
        hasVideo: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RecordedLectureScreen(
          args: const RecordedLectureArgs(
            lectureId: 'lec-1',
            title: 'Constitution Recording',
          ),
          lecturesRepository: fake,
          embedInAppMedia: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recorded lecture'), findsWidgets);
    expect(find.text('Constitution Recording'), findsOneWidget);
    expect(find.text('Polity · UPSC GS'), findsOneWidget);
    expect(find.text('40% watched'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('Get playback link'), findsOneWidget);

    await tester.tap(find.text('Get playback link'));
    await tester.pumpAndSettle();

    expect(fake.playbackCalled, isTrue);
    expect(find.textContaining('cdn.example.test'), findsOneWidget);
    expect(find.textContaining('720p'), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);
  });

  testWidgets('S-26 marks lecture complete', (tester) async {
    final fake = _FakeLectures(
      snapshot: const RecordedLectureSnapshot(
        lectureId: 'lec-2',
        title: 'History Recap',
        progressPercent: 80,
        hasVideo: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RecordedLectureScreen(
          args: const RecordedLectureArgs(lectureId: 'lec-2'),
          lecturesRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();

    expect(fake.completeCalled, isTrue);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Lecture marked complete.'), findsOneWidget);
  });

  testWidgets('S-26 locked state hides actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RecordedLectureScreen(
          args: const RecordedLectureArgs(lectureId: 'lec-3'),
          lecturesRepository: _FakeLectures(
            snapshot: const RecordedLectureSnapshot(
              lectureId: 'lec-3',
              title: 'Locked Lecture',
              accessState: 'locked',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    expect(find.textContaining('locked for your enrollment'), findsOneWidget);
    expect(find.text('Get playback link'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
