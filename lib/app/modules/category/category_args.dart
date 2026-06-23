/// What kind of feed a Category screen should load.
enum CategoryKind { category, genre }

/// Arguments for the generic paged Category list screen.
class CategoryArgs {
  final String title;
  final CategoryKind kind;

  /// For [CategoryKind.category]: one of `movies`/`tv`/`ova`/`completed`.
  /// For [CategoryKind.genre]: the genre slug (e.g. `martial-arts`).
  final String value;

  const CategoryArgs({
    required this.title,
    required this.kind,
    required this.value,
  });
}
