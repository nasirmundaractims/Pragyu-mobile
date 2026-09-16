import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';

void main() {
  test('bucketSubmission groups processing and recent feedback', () {
    final now = DateTime(2026, 9, 16, 12);

    expect(
      bucketSubmission(
        const SubmissionSummary(
          id: 's1',
          assessmentId: 'a1',
          status: 'evaluating',
        ),
        now: now,
      ),
      SubmissionHistoryBucket.processing,
    );

    expect(
      bucketSubmission(
        SubmissionSummary(
          id: 's2',
          assessmentId: 'a1',
          status: 'evaluated',
          evaluatedAt: now.subtract(const Duration(days: 2)),
        ),
        now: now,
      ),
      SubmissionHistoryBucket.feedback,
    );

    expect(
      bucketSubmission(
        SubmissionSummary(
          id: 's3',
          assessmentId: 'a1',
          status: 'evaluated',
          evaluatedAt: now.subtract(const Duration(days: 20)),
        ),
        now: now,
      ),
      SubmissionHistoryBucket.completed,
    );
  });

  test('PastResultsSnapshot computes score summary', () {
    final snapshot = PastResultsSnapshot(
      submissions: [
        const SubmissionSummary(
          id: 's1',
          assessmentId: 'a1',
          status: 'evaluated',
          percentage: 70,
          totalScore: 14,
          maxScore: 20,
        ),
        const SubmissionSummary(
          id: 's2',
          assessmentId: 'a2',
          status: 'evaluated',
          percentage: 90,
          totalScore: 18,
          maxScore: 20,
        ),
        const SubmissionSummary(
          id: 's3',
          assessmentId: 'a3',
          status: 'evaluating',
        ),
      ],
      assessmentTitles: const {
        'a1': 'Polity Quiz',
        'a2': 'History Mock',
      },
    );

    expect(snapshot.scores, hasLength(2));
    expect(snapshot.averagePercentage, 80);
    expect(snapshot.bestPercentage, 90);
    expect(snapshot.titleFor('a1'), 'Polity Quiz');
    expect(
      snapshot.filteredAttempts(SubmissionHistoryTab.processing),
      hasLength(1),
    );
  });
}
