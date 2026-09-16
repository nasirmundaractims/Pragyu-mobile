import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/tests/presentation/widgets/submit_confirm_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('S-44 shows summary and confirms submit', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    confirmed = await showSubmitConfirmSheet(
                      context: context,
                      total: 10,
                      answered: 7,
                      unanswered: 3,
                      marked: 2,
                      unansweredIndexes: const [1, 4, 8],
                      markedIndexes: const [3, 5],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Submit test?'), findsOneWidget);
    expect(
      find.textContaining('cannot change answers'),
      findsOneWidget,
    );
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Answered'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Not answered'), findsOneWidget);
    expect(find.text('3 questions are still unanswered.'), findsOneWidget);
    expect(find.text('Unanswered'), findsOneWidget);
    expect(find.text('Marked for review'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // marked chip index 3+1
    expect(find.text('6'), findsOneWidget); // marked chip index 5+1

    await tester.tap(find.text('Submit now'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });

  testWidgets('S-44 continue cancels; chip jumps to unanswered', (tester) async {
    var confirmed = true;
    int? reviewed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    confirmed = await showSubmitConfirmSheet(
                      context: context,
                      total: 5,
                      answered: 4,
                      unanswered: 1,
                      marked: 0,
                      unansweredIndexes: const [2],
                      onReviewQuestion: (index) => reviewed = index,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue test'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
    expect(reviewed, isNull);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(reviewed, 2);
  });
}
