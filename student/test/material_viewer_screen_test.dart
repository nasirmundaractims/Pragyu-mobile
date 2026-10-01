import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/materials/data/materials_repository.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/materials/presentation/screens/material_viewer_screen.dart';
import 'package:student_mobile/features/notes_bookmarks/data/notes_bookmarks_repository.dart';
import 'package:student_mobile/features/notes_bookmarks/domain/notes_bookmarks_models.dart';

class _FakeMaterials implements MaterialsGateway {
  _FakeMaterials(this.snapshot);

  final MaterialViewerSnapshot snapshot;
  MaterialViewerArgs? lastArgs;

  @override
  Future<StudyMaterialsSnapshot> loadMaterials({
    String? courseId,
    String? courseTitle,
  }) async {
    return const StudyMaterialsSnapshot();
  }

  @override
  Future<MaterialViewerSnapshot> loadMaterialViewer(
    MaterialViewerArgs args,
  ) async {
    lastArgs = args;
    return snapshot;
  }
}

class _FakeBookmarks implements NotesBookmarksGateway {
  NotesBookmarksSnapshot snapshot;
  int addCalls = 0;

  _FakeBookmarks([this.snapshot = const NotesBookmarksSnapshot()]);

  @override
  Future<NotesBookmarksSnapshot> loadLibrary() async => snapshot;

  @override
  Future<StudyNote> createNote({required String body, String? title}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNote(String noteId) async {}

  @override
  Future<ContentBookmark> addBookmark({
    required String bookmarkableType,
    required String bookmarkableId,
    String? title,
  }) async {
    addCalls += 1;
    final bookmark = ContentBookmark(
      id: 'bm-r1',
      bookmarkableType: bookmarkableType,
      bookmarkableId: bookmarkableId,
      title: title,
    );
    snapshot = snapshot.copyWith(bookmarks: [bookmark, ...snapshot.bookmarks]);
    return bookmark;
  }

  @override
  Future<void> removeBookmark(String bookmarkId) async {
    snapshot = snapshot.copyWith(
      bookmarks: snapshot.bookmarks.where((b) => b.id != bookmarkId).toList(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-28 shows open and copy for playable link', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MaterialViewerScreen(
          embedInAppMedia: false,
          args: const MaterialViewerArgs(
            materialId: 'm1',
            title: 'Polity Handout',
          ),
          materialsRepository: _FakeMaterials(
            const MaterialViewerSnapshot(
              id: 'm1',
              title: 'Polity Handout',
              source: MaterialViewerSource.library,
              typeLabel: 'PDF',
              openUrl: 'https://example.test/handout.pdf',
            ),
          ),
          openExternalUrl: (url) async {
            opened.add(url);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polity Handout'), findsWidgets);
    expect(find.text('PDF · Available'), findsOneWidget);
    expect(find.text('Open PDF'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('https://example.test/handout.pdf'), findsOneWidget);
    // Library study materials are not bookmarkable via learning bookmarks API.
    expect(find.byTooltip('Save bookmark'), findsNothing);

    await tester.tap(find.text('Open PDF'));
    await tester.pump();
    expect(opened, ['https://example.test/handout.pdf']);
  });

  testWidgets('S-28 unsupported type shows open-externally CTA', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MaterialViewerScreen(
          embedInAppMedia: true,
          args: const MaterialViewerArgs(
            resourceId: 'r-deck',
            title: 'Slides',
            resourceType: 'presentation',
          ),
          materialsRepository: _FakeMaterials(
            const MaterialViewerSnapshot(
              id: 'r-deck',
              title: 'Slides',
              source: MaterialViewerSource.resource,
              typeLabel: 'Presentation',
              openUrl: 'https://example.test/deck.pptx',
            ),
          ),
          bookmarksRepository: _FakeBookmarks(),
          openExternalUrl: (url) async {
            opened.add(url);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Can’t preview in app'), findsOneWidget);
    expect(find.text('Open externally'), findsOneWidget);
    expect(find.textContaining('open outside Pragyu'), findsOneWidget);

    await tester.tap(find.text('Open externally'));
    await tester.pump();
    expect(opened, ['https://example.test/deck.pptx']);
  });

  testWidgets('S-28 locked state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MaterialViewerScreen(
          embedInAppMedia: false,
          args: const MaterialViewerArgs(materialId: 'm3'),
          materialsRepository: _FakeMaterials(
            const MaterialViewerSnapshot(
              id: 'm3',
              title: 'Premium Deck',
              source: MaterialViewerSource.library,
              typeLabel: 'Presentation',
              isLocked: true,
              errorMessage:
                  'Purchase or enrollment is required to open this study material.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Locked material'), findsOneWidget);
    expect(find.textContaining('Purchase or enrollment'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    expect(find.text('Open externally'), findsNothing);
  });

  testWidgets('S-28 copies link', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MaterialViewerScreen(
          embedInAppMedia: false,
          args: const MaterialViewerArgs(resourceId: 'r1', title: 'Notes'),
          materialsRepository: _FakeMaterials(
            const MaterialViewerSnapshot(
              id: 'r1',
              title: 'Notes PDF',
              source: MaterialViewerSource.resource,
              typeLabel: 'Notes',
              openUrl: 'https://example.test/notes.pdf',
            ),
          ),
          bookmarksRepository: _FakeBookmarks(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy link'));
    await tester.pump();

    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('S-28 resource mode can save bookmark', (tester) async {
    final bookmarks = _FakeBookmarks();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MaterialViewerScreen(
          embedInAppMedia: false,
          args: const MaterialViewerArgs(
            resourceId: 'r1',
            title: 'Notes PDF',
            resourceType: 'pdf',
          ),
          materialsRepository: _FakeMaterials(
            const MaterialViewerSnapshot(
              id: 'r1',
              title: 'Notes PDF',
              source: MaterialViewerSource.resource,
              typeLabel: 'PDF',
              openUrl: 'https://example.test/notes.pdf',
            ),
          ),
          bookmarksRepository: bookmarks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save bookmark'));
    await tester.pumpAndSettle();

    expect(bookmarks.addCalls, 1);
    expect(find.text('Saved to bookmarks'), findsOneWidget);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
  });

  test('MaterialViewerArgs.fromObject accepts StudyMaterial seed', () {
    const material = StudyMaterial(
      id: 'm1',
      title: 'Handout',
      materialType: StudyMaterialKind.pdf,
      externalUrl: 'https://example.test/a.pdf',
    );
    final args = MaterialViewerArgs.fromObject(material);
    expect(args.materialId, 'm1');
    expect(args.externalUrl, 'https://example.test/a.pdf');
    expect(args.isLibraryMode, isTrue);
  });

  test('ContentBookmark.typeForResource maps pdf and video', () {
    expect(ContentBookmark.typeForResource('PDF'), 'pdf');
    expect(ContentBookmark.typeForResource('overview-video'), 'video');
    expect(ContentBookmark.typeForResource('notes'), 'resource');
  });

  test('MaterialViewerSnapshot flags unsupported preview types', () {
    const unsupported = MaterialViewerSnapshot(
      id: '1',
      title: 'Deck',
      source: MaterialViewerSource.resource,
      typeLabel: 'Presentation',
      openUrl: 'https://example.test/a.pptx',
    );
    expect(unsupported.needsExternalOpen, isTrue);
    expect(unsupported.canPreviewInApp, isFalse);

    const pdf = MaterialViewerSnapshot(
      id: '2',
      title: 'Notes',
      source: MaterialViewerSource.resource,
      typeLabel: 'PDF',
      openUrl: 'https://example.test/a.pdf',
    );
    expect(pdf.canPreviewInApp, isTrue);
    expect(pdf.needsExternalOpen, isFalse);
  });
}
