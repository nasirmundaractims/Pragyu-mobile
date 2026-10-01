import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/share/pragyu_share.dart';

void main() {
  tearDown(() {
    PragyuShare.debugHandler = null;
  });

  test('courseUrl and assessmentUrl use default web base', () {
    expect(
      PragyuShare.courseUrl('course-1'),
      'https://pragyu.com/my-courses/course-1',
    );
    expect(
      PragyuShare.assessmentUrl('exam-9'),
      'https://pragyu.com/assessments/exam-9',
    );
  });

  test('shareCourse builds branded caption + course link', () async {
    String? sharedText;
    String? sharedSubject;
    PragyuShare.debugHandler = ({required text, subject}) async {
      sharedText = text;
      sharedSubject = subject;
    };

    await PragyuShare.shareCourse(
      courseId: 'c1',
      title: 'Polity Basics',
      subtitle: 'Week 1',
    );

    expect(sharedSubject, 'Pragyu course · Polity Basics');
    expect(
      sharedText,
      'Learn on Pragyu — Polity Basics\nWeek 1\n\n'
      'https://pragyu.com/my-courses/c1',
    );
  });

  test('shareAssessment builds branded caption + assessment link', () async {
    String? sharedText;
    PragyuShare.debugHandler = ({required text, subject}) async {
      sharedText = text;
    };

    await PragyuShare.shareAssessment(
      assessmentId: 'a1',
      title: 'Mock Prelims',
      detail: 'Due Fri',
    );

    expect(
      sharedText,
      'Learn on Pragyu — Mock Prelims\nDue Fri\n\n'
      'https://pragyu.com/assessments/a1',
    );
  });

  test('shareMentor brands question and appends link', () async {
    String? sharedText;
    String? sharedSubject;
    PragyuShare.debugHandler = ({required text, subject}) async {
      sharedText = text;
      sharedSubject = subject;
    };

    await PragyuShare.shareMentor(
      question: 'What is federalism?',
      link: 'https://pragyu.com/share/ai?d=abc',
    );

    expect(sharedSubject, 'Pragyu AI');
    expect(
      sharedText,
      'Learn on Pragyu — What is federalism?\n'
      'Shared from Pragyu AI Mentor\n\n'
      'https://pragyu.com/share/ai?d=abc',
    );
  });
}
