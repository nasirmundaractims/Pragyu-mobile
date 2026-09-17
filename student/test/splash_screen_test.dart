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

  testWidgets('S-01 splash shows Pragyu brand then opens S-02', (tester) async {
    await tester.pumpWidget(const PragyuApp());
    expect(
      find.image(const AssetImage('assets/images/brand/pragyu-wordmark-light.png')),
      findsOneWidget,
    );
    expect(find.text('Learn with clarity'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('Your Learning Journey'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
