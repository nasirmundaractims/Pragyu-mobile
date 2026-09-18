import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_mobile/app/pragyu_app.dart';
import 'package:student_mobile/core/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets('S-01 splash shows native UI then opens S-02', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PragyuApp());

    expect(find.text('Pragyu'), findsWidgets);
    expect(find.textContaining('Learn'), findsWidgets);
    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('Schools'), findsOneWidget);
    expect(find.text('Learn'), findsWidgets);
    expect(find.text('Practice'), findsWidgets);
    expect(find.text('Loading your learning journey...'), findsOneWidget);
    expect(find.text('BUILT FOR BRIGHTER FUTURES'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/splash/hero_student.png')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/images/splash/splash_screen.png')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.textContaining('Your Preparation'), findsOneWidget);
  });
}
