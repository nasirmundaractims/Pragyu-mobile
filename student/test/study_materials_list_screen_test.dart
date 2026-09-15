import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/materials/data/materials_repository.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';
import 'package:student_mobile/features/materials/presentation/screens/study_materials_list_screen.dart';

class _FakeMaterials implements MaterialsGateway {
  _FakeMaterials(this.snapshot);

  final StudyMaterialsSnapshot snapshot;
  String? lastCourseId;

  @override
  Future<StudyMaterialsSnapshot> loadMaterials({
    String? courseId,
    String? courseTitle,
  }) async {
    lastCourseId = courseId;
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-27 lists materials with type and access', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudyMaterialsListScreen(
          args: const StudyMaterialsListArgs(
            courseId: 'c1',
            courseTitle: 'UPSC GS',
          ),
          materialsRepository: _FakeMaterials(
            const StudyMaterialsSnapshot(
              items: [
                StudyMaterial(
                  id: 'm1',
                  title: 'Polity Handout',
                  materialType: StudyMaterialKind.pdf,
                  accessState: MaterialAccessState.playable,
                  courseTitle: 'UPSC GS',
                ),
                StudyMaterial(
                  id: 'm2',
                  title: 'Revision Notes',
                  materialType: StudyMaterialKind.notes,
                  accessState: MaterialAccessState.free,
                  isFree: true,
                  courseTitle: 'UPSC GS',
                ),
                StudyMaterial(
                  id: 'm3',
                  title: 'Premium Deck',
                  materialType: StudyMaterialKind.presentation,
                  accessState: MaterialAccessState.locked,
                  courseTitle: 'UPSC GS',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Study materials'), findsOneWidget);
    expect(find.textContaining('UPSC GS'), findsWidgets);
    expect(find.text('Polity Handout'), findsOneWidget);
    expect(find.text('Revision Notes'), findsOneWidget);
    expect(find.text('Premium Deck'), findsOneWidget);
    expect(find.text('PDF'), findsWidgets);
    expect(find.text('Notes'), findsWidgets);
  });

  testWidgets('S-27 empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudyMaterialsListScreen(
          materialsRepository: _FakeMaterials(const StudyMaterialsSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No study materials published yet.'), findsOneWidget);
  });

  testWidgets('S-27 locked tap shows message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudyMaterialsListScreen(
          materialsRepository: _FakeMaterials(
            const StudyMaterialsSnapshot(
              items: [
                StudyMaterial(
                  id: 'm3',
                  title: 'Premium Deck',
                  materialType: StudyMaterialKind.presentation,
                  accessState: MaterialAccessState.locked,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Premium Deck'));
    await tester.pump();

    expect(find.textContaining('is locked'), findsOneWidget);
  });

  testWidgets('S-27 openable tap stubs S-28', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudyMaterialsListScreen(
          materialsRepository: _FakeMaterials(
            const StudyMaterialsSnapshot(
              items: [
                StudyMaterial(
                  id: 'm1',
                  title: 'Polity Handout',
                  materialType: StudyMaterialKind.pdf,
                  accessState: MaterialAccessState.playable,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Polity Handout'));
    await tester.pump();

    expect(find.textContaining('S-28'), findsOneWidget);
  });

  test('StudyMaterial.fromJson maps type and access', () {
    final material = StudyMaterial.fromJson({
      'id': 'x',
      'title': 'Map notes',
      'material_type': 'notes',
      'access_state': 'free',
      'is_free': true,
      'media_file_id': 'file-1',
      'external_url': 'https://example.test/notes',
    }, courseId: 'c1', courseTitle: 'GS');

    expect(material.id, 'x');
    expect(material.materialType, StudyMaterialKind.notes);
    expect(material.accessState, MaterialAccessState.free);
    expect(material.canOpen, isTrue);
    expect(material.courseTitle, 'GS');
    expect(material.nextScreenId, 'S-28');
  });
}
