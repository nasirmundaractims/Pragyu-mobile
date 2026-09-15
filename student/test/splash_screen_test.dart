import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/pragyu_app.dart';
import 'package:student_mobile/core/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-01 splash shows Pragyu brand then opens S-02', (tester) async {
    await tester.pumpWidget(const PragyuApp());
    expect(find.text('Pragyu'), findsOneWidget);
    expect(find.text('Learn with clarity'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
