import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/features/exam_series/domain/exam_series_models.dart';

void main() {
  test('ExamSeriesPack parses mine-across fields', () {
    final pack = ExamSeriesPack.fromJson({
      'id': 'es-1',
      'title': 'GPSC Pack',
      'description': 'Mocks and sectionals',
      'item_count': 3,
      'organization_id': 'org-1',
      'organization_name': 'Pragyu Academy',
      'workspace': {'organization_id': 'org-seller', 'hint': 'seller'},
      'items': [
        {
          'id': 'i1',
          'assessment_id': 'a1',
          'assessment_title': 'Mock 1',
          'item_type': 'mock',
          'sort_order': 1,
        },
      ],
    });

    expect(pack.sellerOrganizationId, 'org-seller');
    expect(pack.testsCount, 3);
    expect(pack.fromLabel, 'Pragyu Academy');
    expect(pack.needsOrgSwitch('org-1'), isTrue);
    expect(pack.items.first.displayTitle, 'Mock 1');
  });

  test('ExamSeriesRank disclosed and item type labels', () {
    final rank = ExamSeriesRank.fromJson({
      'disclosed': true,
      'rank': 4,
      'total_marks': 180,
      'cohort_size': 40,
      'assessments_scored': 2,
      'assessments_in_series': 5,
      'assessments_disclosed': 3,
    });
    expect(rank.hasRank, isTrue);
    expect(rank.disclosureBlurb.contains('2/3'), isTrue);

    final item = ExamSeriesItem.fromJson({
      'id': 'i1',
      'assessment_id': 'a1',
      'item_type': 'previous_year',
    });
    expect(item.itemTypeLabel, 'Previous Year');
    expect(item.displayTitle, 'Previous Year');
  });
}
