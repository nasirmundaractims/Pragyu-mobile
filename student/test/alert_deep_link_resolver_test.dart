import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/features/alerts/domain/alert_deep_link_resolver.dart';
import 'package:student_mobile/features/alerts/domain/alerts_models.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

void main() {
  test('parses notification payload IDs and action_url', () {
    final item = AlertItem.fromNotificationJson({
      'id': 'n1',
      'event_type': 'assessment.published',
      'title': 'New test',
      'is_read': false,
      'payload': {
        'assessment_id': 'a-111',
        'action_url': '/assessments/a-111',
        'related_entity_type': 'assessment',
        'related_entity_id': 'a-111',
      },
    });

    expect(item.assessmentId, 'a-111');
    expect(item.actionUrl, '/assessments/a-111');
    expect(item.relatedEntityType, 'assessment');
  });

  test('resolves assessment.published to assessment detail', () {
    const item = AlertItem(
      id: 'n1',
      source: AlertSource.notification,
      title: 'New quiz',
      eventType: 'assessment.published',
      assessmentId: 'a1',
    );

    final target = AlertDeepLinkResolver.resolve(item);
    expect(target?.route, AppRoutes.assessmentDetail);
    expect(target?.arguments, isA<AssessmentDetailArgs>());
    expect((target!.arguments! as AssessmentDetailArgs).assessmentId, 'a1');
  });

  test('resolves evaluation.completed to result feedback', () {
    const item = AlertItem(
      id: 'n2',
      source: AlertSource.notification,
      title: 'Feedback ready',
      eventType: 'evaluation.completed',
      submissionId: 'sub1',
      assessmentId: 'a1',
      evaluationId: 'ev1',
    );

    final target = AlertDeepLinkResolver.resolve(item);
    expect(target?.route, AppRoutes.resultFeedback);
    expect(target?.arguments, isA<ResultFeedbackArgs>());
    expect((target!.arguments! as ResultFeedbackArgs).submissionId, 'sub1');
  });

  test('resolves learning.course_updated to course detail', () {
    const item = AlertItem(
      id: 'n3',
      source: AlertSource.notification,
      title: 'Course updated',
      eventType: 'learning.course_updated',
      courseId: 'c1',
    );

    final target = AlertDeepLinkResolver.resolve(item);
    expect(target?.route, AppRoutes.courseDetail);
    expect((target!.arguments! as CourseDetailArgs).courseId, 'c1');
  });

  test('falls back to action_url path parsing', () {
    const item = AlertItem(
      id: 'n4',
      source: AlertSource.notification,
      title: 'Result',
      actionUrl: 'https://student.pragyu.test/results/sub-99',
    );

    final target = AlertDeepLinkResolver.resolve(item);
    expect(target?.route, AppRoutes.resultFeedback);
    expect((target!.arguments! as ResultFeedbackArgs).submissionId, 'sub-99');
  });

  test('live class reminder without lecture_id opens calendar', () {
    const item = AlertItem(
      id: 'n5',
      source: AlertSource.notification,
      title: 'Live soon',
      eventType: 'learning.live_class_reminder',
    );

    final target = AlertDeepLinkResolver.resolve(item);
    expect(target?.route, AppRoutes.calendar);
  });

  test('unresolvable alert returns null', () {
    const item = AlertItem(
      id: 'n6',
      source: AlertSource.inbox,
      title: 'Announcement',
      eventType: 'engagement.announcement_published',
    );

    expect(AlertDeepLinkResolver.resolve(item), isNull);
  });
}
