/// Endpoints for the Cooren API (anizen provider).
///
/// Base host resolves to api.mugenstream.fun. All anime routes live under
/// `/anime/{provider}`. The provider is fixed to `anizen` for this app.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.mugenstream.fun';
  static const String provider = 'anizen';

  static const String _root = '/anime/$provider';

  /// `GET /anime/anizen/spotlight` → { results: [...] } (home hero items).
  static String spotlight() => '$_root/spotlight';

  /// `GET /anime/anizen/recent-episodes?page=N` → paged { results: [...] }.
  static String recentEpisodes() => '$_root/recent-episodes';

  /// `GET /anime/anizen/search/{query}?page=N` → paged { results: [...] }.
  static String search(String query) => '$_root/search/${Uri.encodeComponent(query)}';

  /// `GET /anime/anizen/info/{id}` → full anime detail incl. episodes list.
  static String info(String id) => '$_root/info/${Uri.encodeComponent(id)}';

  /// `GET /anime/anizen/watch/{episodeId}` → streaming sources.
  ///
  /// NOTE: episodeId contains `$` and `=` characters (e.g.
  /// `naruto-eybxz$ep=1$token=...`) and MUST be percent-encoded.
  static String watch(String episodeId) => '$_root/watch/${Uri.encodeComponent(episodeId)}';

  /// `GET /anime/anizen/schedule/{YYYY-MM-DD}` → { results: [...] }.
  static String schedule(String date) => '$_root/schedule/$date';

  /// Paged category feeds: `movies`, `tv`, `ova`, `completed`.
  /// e.g. `GET /anime/anizen/movies?page=N`.
  static String category(String kind) => '$_root/$kind';

  /// `GET /anime/anizen/genre/{name}?page=N` (name is lower-kebab, e.g.
  /// `martial-arts`).
  static String genre(String name) => '$_root/genre/$name';
}
