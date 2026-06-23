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

  /// Standard anime genres. Display name maps to the API slug
  /// (lower-case, spaces → hyphens).
  static const List<String> genres = [
    'Action', 'Adventure', 'Cars', 'Comedy', 'Dementia', 'Demons',
    'Drama', 'Ecchi', 'Fantasy', 'Game', 'Harem', 'Historical',
    'Horror', 'Isekai', 'Josei', 'Kids', 'Magic', 'Martial Arts',
    'Mecha', 'Military', 'Music', 'Mystery', 'Parody', 'Police',
    'Psychological', 'Romance', 'Samurai', 'School', 'Sci-Fi', 'Seinen',
    'Shoujo', 'Shounen', 'Slice of Life', 'Space', 'Sports', 'Super Power',
    'Supernatural', 'Thriller', 'Vampire',
  ];

  /// Convert a display genre into the API slug, e.g. "Super Power" → "super-power".
  static String genreSlug(String name) =>
      name.toLowerCase().replaceAll(' ', '-');
}
