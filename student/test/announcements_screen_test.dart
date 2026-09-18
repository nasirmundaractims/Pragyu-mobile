import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/announcements/data/announcements_repository.dart';
import 'package:student_mobile/features/announcements/domain/announcements_models.dart';
import 'package:student_mobile/features/announcements/presentation/screens/announcement_detail_screen.dart';
import 'package:student_mobile/features/announcements/presentation/screens/announcements_screen.dart';

class _FakeAnnouncements implements AnnouncementsGateway {
  _FakeAnnouncements(this.items);

  final List<AnnouncementItem> items;
  final marked = <String>[];

  @override
  Future<AnnouncementsSnapshot> loadAnnouncements() async {
    return AnnouncementsSnapshot(items: items);
  }

  @override
  Future<AnnouncementItem?> findById(String announcementId) async {
    for (final item in items) {
      if (item.id == announcementId) return item;
    }
    return null;
  }

  @override
  Future<void> markRead(String announcementId) async {
    marked.add(announcementId);
  }
}

void main() {
  test('AnnouncementItem strips HTML body', () {
    final item = AnnouncementItem.fromJson({
      'id': 'a1',
      'title': 'Welcome Week',
      'body': '<p>Orientation starts <strong>Monday</strong>.</p>',
      'announcement_type': 'academic',
      'is_pinned': true,
      'published_at': '2026-09-18T10:00:00Z',
    });

    expect(item.isPinned, isTrue);
    expect(item.typeLabel, 'Academic');
    expect(item.plainBody, contains('Orientation starts'));
    expect(item.plainBody, isNot(contains('<strong>')));
  });

  testWidgets('S-69 list shows pinned and recent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeAnnouncements([
      const AnnouncementItem(
        id: 'a1',
        title: 'Pinned notice',
        body: 'Read me first.',
        isPinned: true,
        announcementType: 'general',
      ),
      const AnnouncementItem(
        id: 'a2',
        title: 'Recent notice',
        body: 'Later update.',
        announcementType: 'academic',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.announcementDetail) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => AnnouncementDetailScreen(
                args: AnnouncementDetailArgs.fromObject(settings.arguments),
                announcementsRepository: fake,
              ),
            );
          }
          return null;
        },
        home: AnnouncementsScreen(announcementsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Pinned notice'), findsOneWidget);
    expect(find.text('Recent notice'), findsOneWidget);

    await tester.tap(find.text('Pinned notice'));
    await tester.pumpAndSettle();

    expect(find.text('Pinned notice'), findsWidgets);
    expect(find.textContaining('Read me first'), findsOneWidget);
    expect(fake.marked, contains('a1'));
  });

  testWidgets('S-69 empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AnnouncementsScreen(
          announcementsRepository: _FakeAnnouncements(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No announcements yet'), findsOneWidget);
  });
}
