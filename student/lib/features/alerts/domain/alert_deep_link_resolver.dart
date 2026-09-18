import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/features/alerts/domain/alerts_models.dart';
import 'package:student_mobile/features/announcements/domain/announcements_models.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

/// Resolved navigation target for an alert / push payload (S-51).
class AlertDeepLinkTarget {
  const AlertDeepLinkTarget({
    required this.route,
    this.arguments,
    this.label,
  });

  final String route;
  final Object? arguments;
  final String? label;
}

/// Maps notification / inbox payloads to AppRoutes + args.
abstract final class AlertDeepLinkResolver {
  static AlertDeepLinkTarget? resolve(AlertItem item) {
    final fromEvent = _fromEventType(item);
    if (fromEvent != null) return fromEvent;
    return _fromActionUrl(item.actionUrl) ?? _fromRelatedEntity(item);
  }

  static bool canOpen(AlertItem item) => resolve(item) != null;

  static AlertDeepLinkTarget? _fromEventType(AlertItem item) {
    final type = (item.eventType ?? '').toLowerCase().trim();
    if (type.isEmpty) return null;

    switch (type) {
      case 'assessment.published':
        final id = item.assessmentId;
        if (id == null) return null;
        return AlertDeepLinkTarget(
          route: AppRoutes.assessmentDetail,
          arguments: AssessmentDetailArgs(assessmentId: id, title: item.title),
          label: 'Open assessment',
        );

      case 'evaluation.completed':
        final submissionId = item.submissionId;
        if (submissionId == null) return null;
        return AlertDeepLinkTarget(
          route: AppRoutes.resultFeedback,
          arguments: ResultFeedbackArgs(
            submissionId: submissionId,
            assessmentId: item.assessmentId,
            title: item.title,
          ),
          label: 'Open result',
        );

      case 'evaluation.started':
      case 'evaluation.failed':
        final submissionId = item.submissionId;
        if (submissionId != null) {
          return AlertDeepLinkTarget(
            route: AppRoutes.submissionStatus,
            arguments: SubmissionStatusArgs(
              submissionId: submissionId,
              assessmentId: item.assessmentId,
              title: item.title,
              initialStatus: type.contains('failed') ? 'failed' : 'evaluating',
            ),
            label: 'Open submission status',
          );
        }
        return const AlertDeepLinkTarget(
          route: AppRoutes.pastResults,
          label: 'Open attempts',
        );

      case 'rewrite.completed':
        final evaluationId = item.evaluationId;
        final submissionId = item.submissionId;
        if (evaluationId != null &&
            submissionId != null &&
            evaluationId.isNotEmpty &&
            submissionId.isNotEmpty) {
          return AlertDeepLinkTarget(
            route: AppRoutes.deepFeedback,
            arguments: DeepFeedbackArgs(
              submissionId: submissionId,
              evaluationId: evaluationId,
              assessmentId: item.assessmentId,
              title: item.title,
            ),
            label: 'Open AI answer',
          );
        }
        if (submissionId != null) {
          return AlertDeepLinkTarget(
            route: AppRoutes.resultFeedback,
            arguments: ResultFeedbackArgs(
              submissionId: submissionId,
              assessmentId: item.assessmentId,
              title: item.title,
            ),
            label: 'Open result',
          );
        }
        return const AlertDeepLinkTarget(
          route: AppRoutes.pastResults,
          label: 'Open attempts',
        );

      case 'study_material.published':
        final materialId = item.materialId;
        if (materialId != null) {
          return AlertDeepLinkTarget(
            route: AppRoutes.materialViewer,
            arguments: MaterialViewerArgs(
              materialId: materialId,
              title: item.title,
            ),
            label: 'Open material',
          );
        }
        return AlertDeepLinkTarget(
          route: AppRoutes.studyMaterials,
          arguments: StudyMaterialsListArgs(courseId: item.courseId),
          label: 'Open materials',
        );

      case 'engagement.announcement_published':
      case 'announcement.published':
        final announcementId = item.relatedEntityId;
        if (announcementId != null && announcementId.isNotEmpty) {
          return AlertDeepLinkTarget(
            route: AppRoutes.announcementDetail,
            arguments: AnnouncementDetailArgs(announcementId: announcementId),
            label: 'Open announcement',
          );
        }
        return const AlertDeepLinkTarget(
          route: AppRoutes.announcements,
          label: 'Open announcements',
        );

      case 'learning.lesson_published':
      case 'learning.assignment_available':
        final lessonId = item.lessonId;
        if (lessonId != null) {
          return AlertDeepLinkTarget(
            route: AppRoutes.lessonPlayer,
            arguments: LessonDetailArgs(
              lessonId: lessonId,
              courseId: item.courseId,
              title: item.title,
            ),
            label: 'Open lesson',
          );
        }
        final resourceId = item.resourceId;
        if (resourceId != null) {
          return AlertDeepLinkTarget(
            route: AppRoutes.materialViewer,
            arguments: MaterialViewerArgs(
              resourceId: resourceId,
              title: item.title,
            ),
            label: 'Open resource',
          );
        }
        final courseId = item.courseId;
        if (courseId != null) {
          return AlertDeepLinkTarget(
            route: AppRoutes.courseDetail,
            arguments: CourseDetailArgs(courseId: courseId, title: item.title),
            label: 'Open course',
          );
        }
        return null;

      case 'learning.course_updated':
        final courseId = item.courseId;
        if (courseId == null) return null;
        return AlertDeepLinkTarget(
          route: AppRoutes.courseDetail,
          arguments: CourseDetailArgs(courseId: courseId, title: item.title),
          label: 'Open course',
        );

      case 'learning.live_class_reminder':
        final lectureId = item.lectureId;
        if (lectureId != null) {
          return AlertDeepLinkTarget(
            route: AppRoutes.liveLobby,
            arguments: LiveLobbyArgs(lectureId: lectureId),
            label: 'Join live class',
          );
        }
        return const AlertDeepLinkTarget(
          route: AppRoutes.calendar,
          label: 'Open calendar',
        );

      default:
        if (type.contains('assessment')) {
          final id = item.assessmentId;
          if (id != null) {
            return AlertDeepLinkTarget(
              route: AppRoutes.assessmentDetail,
              arguments: AssessmentDetailArgs(assessmentId: id),
              label: 'Open assessment',
            );
          }
        }
        if (type.contains('evaluation') || type.contains('result')) {
          final submissionId = item.submissionId;
          if (submissionId != null) {
            return AlertDeepLinkTarget(
              route: AppRoutes.resultFeedback,
              arguments: ResultFeedbackArgs(submissionId: submissionId),
              label: 'Open result',
            );
          }
          return const AlertDeepLinkTarget(
            route: AppRoutes.pastResults,
            label: 'Open attempts',
          );
        }
        return null;
    }
  }

  static AlertDeepLinkTarget? _fromActionUrl(String? actionUrl) {
    if (actionUrl == null || actionUrl.trim().isEmpty) return null;
    final path = _normalizePath(actionUrl);
    if (path == null) return null;

    final assessment = RegExp(r'^/assessments/([^/]+)/?$').firstMatch(path);
    if (assessment != null) {
      return AlertDeepLinkTarget(
        route: AppRoutes.assessmentDetail,
        arguments: AssessmentDetailArgs(assessmentId: assessment.group(1)!),
        label: 'Open assessment',
      );
    }

    final results = RegExp(r'^/results/([^/]+)/?$').firstMatch(path);
    if (results != null) {
      return AlertDeepLinkTarget(
        route: AppRoutes.resultFeedback,
        arguments: ResultFeedbackArgs(submissionId: results.group(1)!),
        label: 'Open result',
      );
    }

    final submissions = RegExp(r'^/submissions/([^/]+)/?$').firstMatch(path);
    if (submissions != null) {
      return AlertDeepLinkTarget(
        route: AppRoutes.resultFeedback,
        arguments: ResultFeedbackArgs(submissionId: submissions.group(1)!),
        label: 'Open result',
      );
    }

    final lessons = RegExp(r'^/lessons/([^/]+)/?$').firstMatch(path);
    if (lessons != null) {
      return AlertDeepLinkTarget(
        route: AppRoutes.lessonPlayer,
        arguments: LessonDetailArgs(lessonId: lessons.group(1)!),
        label: 'Open lesson',
      );
    }

    final courses = RegExp(r'^/(?:courses|my-courses)/([^/]+)/?$').firstMatch(path);
    if (courses != null) {
      return AlertDeepLinkTarget(
        route: AppRoutes.courseDetail,
        arguments: CourseDetailArgs(courseId: courses.group(1)!),
        label: 'Open course',
      );
    }

    final lectures = RegExp(r'^/lectures/([^/]+)(?:/live)?/?$').firstMatch(path);
    if (lectures != null) {
      return AlertDeepLinkTarget(
        route: AppRoutes.liveLobby,
        arguments: LiveLobbyArgs(lectureId: lectures.group(1)!),
        label: 'Open lecture',
      );
    }

    final announcements = RegExp(r'^/announcements/([^/]+)/?$').firstMatch(path);
    if (announcements != null) {
      return AlertDeepLinkTarget(
        route: AppRoutes.announcementDetail,
        arguments: AnnouncementDetailArgs(
          announcementId: announcements.group(1)!,
        ),
        label: 'Open announcement',
      );
    }

    if (path == '/announcements') {
      return const AlertDeepLinkTarget(
        route: AppRoutes.announcements,
        label: 'Open announcements',
      );
    }

    if (path == '/study-materials' || path.startsWith('/study-materials')) {
      return const AlertDeepLinkTarget(
        route: AppRoutes.studyMaterials,
        label: 'Open materials',
      );
    }

    if (path == '/calendar' || path.startsWith('/calendar')) {
      return const AlertDeepLinkTarget(
        route: AppRoutes.calendar,
        label: 'Open calendar',
      );
    }

    if (path == '/results' || path == '/assessments') {
      return const AlertDeepLinkTarget(
        route: AppRoutes.pastResults,
        label: 'Open attempts',
      );
    }

    final rewrites = RegExp(r'^/rewrites/([^/]+)/?$').firstMatch(path);
    if (rewrites != null) {
      return const AlertDeepLinkTarget(
        route: AppRoutes.pastResults,
        label: 'Open attempts',
      );
    }

    return null;
  }

  static AlertDeepLinkTarget? _fromRelatedEntity(AlertItem item) {
    final type = (item.relatedEntityType ?? '').toLowerCase();
    final id = item.relatedEntityId;
    if (id == null || id.isEmpty) return null;

    switch (type) {
      case 'assessment':
        return AlertDeepLinkTarget(
          route: AppRoutes.assessmentDetail,
          arguments: AssessmentDetailArgs(assessmentId: id),
          label: 'Open assessment',
        );
      case 'study_material':
        return AlertDeepLinkTarget(
          route: AppRoutes.materialViewer,
          arguments: MaterialViewerArgs(materialId: id),
          label: 'Open material',
        );
      case 'learning':
      case 'course':
        return AlertDeepLinkTarget(
          route: AppRoutes.courseDetail,
          arguments: CourseDetailArgs(courseId: id),
          label: 'Open course',
        );
      case 'engagement_announcement':
      case 'announcement':
        return AlertDeepLinkTarget(
          route: AppRoutes.announcementDetail,
          arguments: AnnouncementDetailArgs(announcementId: id),
          label: 'Open announcement',
        );
      case 'lesson':
        return AlertDeepLinkTarget(
          route: AppRoutes.lessonPlayer,
          arguments: LessonDetailArgs(lessonId: id),
          label: 'Open lesson',
        );
      case 'lecture':
        return AlertDeepLinkTarget(
          route: AppRoutes.liveLobby,
          arguments: LiveLobbyArgs(lectureId: id),
          label: 'Open lecture',
        );
      case 'submission':
      case 'answer_submission':
        return AlertDeepLinkTarget(
          route: AppRoutes.resultFeedback,
          arguments: ResultFeedbackArgs(submissionId: id),
          label: 'Open result',
        );
      default:
        return null;
    }
  }

  static String? _normalizePath(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    try {
      final uri = Uri.parse(value);
      if (uri.hasScheme || value.startsWith('//')) {
        value = uri.path;
      }
    } catch (_) {}
    if (!value.startsWith('/')) {
      value = '/$value';
    }
    // Strip query/hash leftovers if present.
    final q = value.indexOf('?');
    if (q >= 0) value = value.substring(0, q);
    final h = value.indexOf('#');
    if (h >= 0) value = value.substring(0, h);
    return value.isEmpty ? null : value;
  }
}
