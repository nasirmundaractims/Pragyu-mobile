import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/lectures/presentation/screens/lectures_list_screen.dart';

class _FakeLectures implements LecturesGateway {
  _FakeLectures(this.snapshot);

  final LecturesSnapshot snapshot;

  @override
  Future<LecturesSnapshot> loadLectures({String? courseId}) async => snapshot;

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
    return LiveChatMessage(id: 'm1', body: body);
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
    return const LecturePlaybackInfo(
      playbackUrl: 'https://example.test/video.m3u8',
    );
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
      hasVideo: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-23 groups live, upcoming, and recorded', (tester) async {
    final now = DateTime(2026, 9, 15, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LecturesListScreen(
          args: const LecturesListArgs(courseTitle: 'UPSC GS'),
          lecturesRepository: _FakeLectures(
            LecturesSnapshot.fromItems(
              [
                LectureItem(
                  id: '1',
                  title: 'Live Polity Session',
                  subjectName: 'Polity',
                  lectureType: 'live',
                  sessionStatus: 'live',
                ),
                LectureItem(
                  id: '2',
                  title: 'Evening History',
                  lectureType: 'live',
                  startsAt: now.add(const Duration(hours: 3)),
                ),
                const LectureItem(
                  id: '3',
                  title: 'Constitution Recording',
                  lectureType: 'recorded',
                  durationSeconds: 1800,
                  hasVideo: true,
                ),
              ],
              now: now,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lectures'), findsOneWidget);
    expect(find.textContaining('UPSC GS'), findsOneWidget);
    expect(find.text('Live now'), findsOneWidget);
    expect(find.text('Live Polity Session'), findsOneWidget);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Evening History'), findsOneWidget);
    expect(find.text('Recorded'), findsWidgets);
    expect(find.text('Constitution Recording'), findsOneWidget);
  });

  testWidgets('S-23 empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LecturesListScreen(
          lecturesRepository: _FakeLectures(const LecturesSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No lectures published yet.'), findsOneWidget);
  });

  test('LecturesSnapshot classifies kinds', () {
    final now = DateTime(2026, 9, 15, 12);
    final snapshot = LecturesSnapshot.fromItems(
      [
        LectureItem(
          id: 'a',
          title: 'A',
          sessionStatus: 'waiting',
          lectureType: 'live',
        ),
        LectureItem(
          id: 'b',
          title: 'B',
          lectureType: 'live',
          startsAt: now.add(const Duration(days: 1)),
        ),
        const LectureItem(
          id: 'c',
          title: 'C',
          lectureType: 'recorded',
        ),
      ],
      now: now,
    );

    expect(snapshot.live.single.id, 'a');
    expect(snapshot.upcoming.single.id, 'b');
    expect(snapshot.recorded.single.id, 'c');
  });
}
