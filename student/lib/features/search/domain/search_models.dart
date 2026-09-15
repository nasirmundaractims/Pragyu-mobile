enum SearchHitKind { course, test, material }

class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.kind,
    this.subtitle,
    this.materialType,
  });

  final String id;
  final String title;
  final SearchHitKind kind;
  final String? subtitle;
  final String? materialType;

  String get kindLabel {
    switch (kind) {
      case SearchHitKind.course:
        return 'Course';
      case SearchHitKind.test:
        return 'Test';
      case SearchHitKind.material:
        return materialType == null || materialType!.isEmpty
            ? 'Material'
            : materialType!;
    }
  }

  int get tabIndex {
    switch (kind) {
      case SearchHitKind.course:
      case SearchHitKind.material:
        return 1; // Learn
      case SearchHitKind.test:
        return 2; // Tests
    }
  }

  String get nextScreenId {
    switch (kind) {
      case SearchHitKind.course:
        return 'S-21';
      case SearchHitKind.test:
        return 'S-41';
      case SearchHitKind.material:
        return 'S-28';
    }
  }
}

class QuickSearchCatalog {
  const QuickSearchCatalog({
    this.courses = const [],
    this.tests = const [],
  });

  final List<SearchHit> courses;
  final List<SearchHit> tests;
}

class QuickSearchResults {
  const QuickSearchResults({
    this.courses = const [],
    this.tests = const [],
    this.materials = const [],
  });

  final List<SearchHit> courses;
  final List<SearchHit> tests;
  final List<SearchHit> materials;

  bool get isEmpty =>
      courses.isEmpty && tests.isEmpty && materials.isEmpty;

  List<SearchHit> get all => [...courses, ...tests, ...materials];
}
