import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/lectures/data/lectures_repository.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/lectures/presentation/screens/live_room_screen.dart';

class _FakeLectures implements LecturesGateway {
  final List<LiveChatMessage> messages = [
    const LiveChatMessage(
      id: '1',
      body: 'Hello class',
      authorRole: 'faculty',
    ),
  ];
  bool heartbeatCalled = false;
  int postCount = 0;

  @override
  Future<LecturesSnapshot> loadLectures({String? courseId}) async {
    return const LecturesSnapshot();
  }

  @override
  Future<LiveLobbySnapshot> loadLiveLobby(String lectureId) async {
    return LiveLobbySnapshot(
      lectureId: lectureId,
      title: 'Room',
      sessionStatus: LiveSessionStatus.live,
    );
  }

  @override
  Future<LiveJoinResult> joinLive(String lectureId) async {
    return const LiveJoinResult(
      inWaitingRoom: false,
      hasMediaToken: true,
    );
  }

  @override
  Future<List<LiveChatMessage>> listLiveChat(String lectureId) async {
    return List.unmodifiable(messages);
  }

  @override
  Future<LiveChatMessage> postLiveChat(String lectureId, String body) async {
    postCount += 1;
    final message = LiveChatMessage(
      id: 'm$postCount',
      body: body,
      authorRole: 'student',
    );
    messages.add(message);
    return message;
  }

  @override
  Future<void> sendAttendanceHeartbeat(String lectureId) async {
    heartbeatCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-25 shows stub media and chat', (tester) async {
    final fake = _FakeLectures();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LiveRoomScreen(
          args: const LiveRoomArgs(
            lectureId: 'lec-1',
            title: 'Evening Class',
            mediaUrl: 'https://example.test/room',
          ),
          lecturesRepository: fake,
          chatPollInterval: null,
          heartbeatInterval: null,
        ),
      ),
    );
    // Initial heartbeat is fired in initState.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Live room'), findsOneWidget);
    expect(find.text('Evening Class'), findsOneWidget);
    expect(find.textContaining('Media connected'), findsOneWidget);
    expect(find.text('Hello class'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(fake.heartbeatCalled, isTrue);
  });

  testWidgets('S-25 sends chat message', (tester) async {
    final fake = _FakeLectures();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LiveRoomScreen(
          args: const LiveRoomArgs(lectureId: 'lec-1', title: 'Class'),
          lecturesRepository: fake,
          chatPollInterval: null,
          heartbeatInterval: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Thanks!');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(fake.postCount, 1);
    expect(find.text('Thanks!'), findsOneWidget);
  });

  testWidgets('S-25 leave pops room', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LiveRoomScreen(
                          args: const LiveRoomArgs(
                            lectureId: 'lec-1',
                            title: 'Class',
                          ),
                          lecturesRepository: _FakeLectures(),
                          chatPollInterval: null,
                          heartbeatInterval: null,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open room'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open room'));
    await tester.pumpAndSettle();
    expect(find.text('Live room'), findsOneWidget);

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Open room'), findsOneWidget);
  });
}
