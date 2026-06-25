/// Static catalogues used by the Explore screen.
class AppConstants {
  AppConstants._();

  /// Browse categories backed by paged API feeds.
  /// `kind` is the path segment (`movies`, `tv`, `ova`, `completed`).
  static const List<({String label, String kind})> categories = [
    (label: 'Movies', kind: 'movies'),
    (label: 'TV Series', kind: 'tv'),
    (label: 'OVA', kind: 'ova'),
    (label: 'Completed', kind: 'completed'),
  ];

  /// Genres the `animelok` provider actually returns titles for. The full
  /// standard genre set was curated down to these against the live API — the
  /// other ~22 (Cars, Super Power, Isekai, Shounen, Martial Arts, School, …)
  /// return zero results from the provider's genre filter, so listing them only
  /// leads to dead "nothing here" screens. Re-audit the genre endpoint if the
  /// provider changes (see the genre-endpoint-slug-format note).
  static const List<String> genres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Ecchi', 'Fantasy',
    'Horror', 'Mecha', 'Music', 'Mystery', 'Psychological', 'Romance',
    'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural', 'Thriller',
  ];

  /// Convert a display genre into the API slug. The provider matches genres by
  /// their lower-cased name WITH spaces preserved (e.g. "Slice of Life" →
  /// "slice of life"); hyphenating multi-word genres returns zero results.
  /// [ApiConstants.genre] percent-encodes the spaces.
  static String genreSlug(String name) => name.toLowerCase();
}
