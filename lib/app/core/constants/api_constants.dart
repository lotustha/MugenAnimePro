/// Endpoints for the Cooren API.
///
/// Base host resolves to api.mugenstream.fun. All anime routes live under
/// `/anime/{provider}`.
///
/// [provider] is NOT const — it can be overridden at runtime from Firebase
/// Remote Config (key `anime_provider`) so the backend provider can be switched
/// (animelok / anivid / anizen / …) without shipping an app update. Default is
/// `animelok` — multi-language (japanese, english, hindi, tamil, telugu, …),
/// each language served by its own working server. See RemoteSettingsService.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.mugenstream.fun';
  static String provider = 'animelok';

  /// Mugenstream website (posts, wallpapers, in-app messages, FCM token
  /// registration). Distinct from [baseUrl], which is the anime streaming API.
  static const String siteUrl = 'https://mugenstream.fun';

  /// `POST/DELETE /api/notifications` — register/remove this device's FCM token.
  static String notifications() => '$siteUrl/api/notifications';

  /// `GET /api/in-app-messages?app={slug}&deviceId={id}` — active overlay messages.
  static String inAppMessages() => '$siteUrl/api/in-app-messages';

  /// `POST /api/in-app-messages/track` — record an impression/click.
  static String inAppMessagesTrack() => '$siteUrl/api/in-app-messages/track';

  // ── Website content (used with SiteClient, whose baseUrl is [siteUrl]) ──────

  /// `GET /api/posts?limit=&page=` — news article list.
  static const String posts = '/api/posts';

  /// `GET /api/posts/{slug}` — single article with full HTML content.
  static String post(String slug) => '/api/posts/$slug';

  /// `GET /api/wallpapers?type=&page=&limit=` — wallpaper gallery.
  static const String wallpapers = '/api/wallpapers';

  /// `GET /api/wallpapers/{id}` — single wallpaper.
  static String wallpaper(String id) => '/api/wallpapers/$id';

  /// `GET /api/wallpaper-categories` — list of categories with counts.
  static const String wallpaperCategories = '/api/wallpaper-categories';

  /// `GET /api/wallpapers/search?q=&limit=&type=` — wallpaper search.
  static const String wallpaperSearch = '/api/wallpapers/search';

  static String get _root => '/anime/$provider';

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

  /// `GET /anime/anizen/genre/{name}?page=N`. [name] is the lower-cased genre
  /// with spaces (e.g. `slice of life`); it MUST be percent-encoded because the
  /// provider matches on the spaced name, not a hyphenated slug.
  static String genre(String name) => '$_root/genre/${Uri.encodeComponent(name)}';
}
