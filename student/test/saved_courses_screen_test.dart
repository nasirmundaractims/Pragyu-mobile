import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/catalog/data/catalog_repository.dart';
import 'package:student_mobile/features/catalog/data/wishlist_repository.dart';
import 'package:student_mobile/features/catalog/domain/catalog_models.dart';
import 'package:student_mobile/features/catalog/domain/wishlist_models.dart';
import 'package:student_mobile/features/catalog/presentation/screens/catalog_detail_screen.dart';
import 'package:student_mobile/features/catalog/presentation/screens/saved_courses_screen.dart';

class _FakeWishlist implements WishlistGateway {
  _FakeWishlist([this.snapshot = const WishlistSnapshot()]);

  WishlistSnapshot snapshot;
  final List<String> savedCalls = [];
  final List<String> removedCalls = [];

  @override
  Future<WishlistSnapshot> loadWishlist({int limit = 100}) async => snapshot;

  @override
  Future<void> saveListing(String listingId) async {
    savedCalls.add(listingId);
    snapshot = snapshot.withAdded(
      CatalogListing(
        id: listingId,
        slug: 'slug-$listingId',
        title: 'Saved $listingId',
        price: 499,
        currency: 'INR',
      ),
    );
  }

  @override
  Future<void> removeListing(String listingId) async {
    removedCalls.add(listingId);
    snapshot = snapshot.withoutListing(listingId);
  }

  @override
  Future<bool> isSaved(String listingId) async =>
      snapshot.containsListing(listingId);
}

class _FakeCatalog implements CatalogGateway {
  _FakeCatalog(this.listing);

  final CatalogListing listing;

  @override
  Future<CatalogSnapshot> loadCatalog({
    String? query,
    int offset = 0,
  }) async {
    return CatalogSnapshot(items: [listing]);
  }

  @override
  Future<CatalogListing> loadListing(String slug) async => listing;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WishlistSnapshot parses listing cards', () {
    final snapshot = WishlistSnapshot.fromJson({
      'count': 1,
      'items': [
        {
          'id': 'l1',
          'slug': 'polity-crash',
          'title': 'Polity Crash',
          'price': 999,
          'currency': 'INR',
        },
      ],
    });

    expect(snapshot.count, 1);
    expect(snapshot.items.single.id, 'l1');
    expect(snapshot.containsListing('l1'), isTrue);
    expect(snapshot.withoutListing('l1').isEmpty, isTrue);
  });

  testWidgets('5.2 saved courses lists and removes', (tester) async {
    final fake = _FakeWishlist(
      WishlistSnapshot(
        count: 1,
        items: const [
          CatalogListing(
            id: 'l1',
            slug: 'polity-crash',
            title: 'Polity Crash',
            price: 999,
            currency: 'INR',
            sellerName: 'Pragyu Academy',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SavedCoursesScreen(wishlistRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved courses'), findsOneWidget);
    expect(find.text('Polity Crash'), findsOneWidget);
    expect(find.text('₹999'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(fake.removedCalls, contains('l1'));
    expect(find.text('No saved courses yet'), findsOneWidget);
  });

  testWidgets('5.2 catalog detail saves listing', (tester) async {
    final listing = const CatalogListing(
      id: 'l1',
      slug: 'polity-crash',
      title: 'Polity Crash',
      price: 999,
      currency: 'INR',
      programId: 'p1',
      courseId: 'c1',
    );
    final wishlist = _FakeWishlist();
    final catalog = _FakeCatalog(listing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CatalogDetailScreen(
          slug: 'polity-crash',
          catalogRepository: catalog,
          wishlistRepository: wishlist,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polity Crash'), findsWidgets);
    expect(find.text('Save for later'), findsOneWidget);

    await tester.tap(find.text('Save for later'));
    await tester.pumpAndSettle();

    expect(wishlist.savedCalls, contains('l1'));
    expect(find.text('Saved'), findsOneWidget);
    expect(find.textContaining('Saved for later'), findsOneWidget);
  });

  testWidgets('5.2 empty saved courses offers browse CTA', (tester) async {
    Object? pushedRoute;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SavedCoursesScreen(wishlistRepository: _FakeWishlist()),
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Catalog')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved courses yet'), findsOneWidget);
    await tester.tap(find.text('Browse catalog'));
    await tester.pumpAndSettle();
    expect(pushedRoute, '/catalog');
  });
}
