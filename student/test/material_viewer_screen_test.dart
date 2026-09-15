import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/materials/data/materials_repository.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/materials/presentation/screens/material_viewer_screen.dart';

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
    expect(find.textContaining('PDF'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('https://example.test/handout.pdf'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(opened, ['https://example.test/handout.pdf']);
  });

  testWidgets('S-28 locked state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MaterialViewerScreen(
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy link'));
    await tester.pump();

    expect(find.text('Link copied.'), findsOneWidget);
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
}
