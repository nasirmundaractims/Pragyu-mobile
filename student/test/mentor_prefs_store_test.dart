import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_mobile/features/ai_mentor/data/mentor_prefs_store.dart';
import 'package:student_mobile/features/ai_mentor/presentation/mentor_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('toggleLike persists and clears dislike', () async {
    final store = MentorPrefsStore();
    var prefs = const MentorPrefs();

    prefs = await store.setDislike(
      studentProfileId: 'sp-1',
      current: prefs,
      messageId: 'm1',
      reason: 'Other',
    );
    expect(prefs.disliked, contains('m1'));
    expect(prefs.dislikeReasons['m1'], 'Other');

    prefs = await store.toggleLike(
      studentProfileId: 'sp-1',
      current: prefs,
      messageId: 'm1',
    );
    expect(prefs.liked, contains('m1'));
    expect(prefs.disliked, isEmpty);
    expect(prefs.dislikeReasons, isEmpty);

    final reloaded = await store.load('sp-1');
    expect(reloaded.liked, contains('m1'));
  });

  test('mentorShareLink encodes payload', () {
    final link = mentorShareLink(
      question: 'Explain federalism',
      answer: 'Federalism divides power.',
    );
    expect(link, startsWith('https://pragyu.com/share/ai?d='));
    final data = link.split('?d=').last;
    expect(data, isNotEmpty);
    expect(data.contains('+'), isFalse);
    expect(data.contains('/'), isFalse);
  });
}
