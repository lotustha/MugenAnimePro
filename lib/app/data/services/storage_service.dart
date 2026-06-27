import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/constants/api_constants.dart';
import '../models/anime.dart';
import '../models/watch_progress.dart';
import 'push_service.dart';

/// Local persistence backed by GetStorage. Holds favorites, "continue
/// watching" progress and lightweight user preferences.
///
/// Exposes reactive lists so the UI updates instantly on change.
class StorageService extends GetxService {
  // Favorites / history / watched / reminders are namespaced PER PROVIDER, so
  // switching the streaming provider (Remote Config) gives a fresh set without
  // destroying the old one — switch back and the data is restored. Anime IDs
  // differ across providers, so a shared store wouldn't resolve anyway.
  String get _favoritesKey => 'favorites_${ApiConstants.provider}';
  String get _progressKey => 'watch_progress_${ApiConstants.provider}';
  String get _watchedKey => 'watched_episodes_${ApiConstants.provider}';
  String get _notifyKey => 'notify_anime_${ApiConstants.provider}';

  // Preferences are global (provider-independent).
  static const _preferDubKey = 'prefer_dub';
  static const _preferredLanguageKey = 'preferred_language';
  static const _episodesAscendingKey = 'episodes_ascending';

  final GetStorage _box = GetStorage();

  final RxList<Anime> favorites = <Anime>[].obs;
  final RxList<WatchProgress> continueWatching = <WatchProgress>[].obs;

  /// animeId -> set of watched episode numbers.
  final Map<String, Set<int>> _watched = {};

  /// animeId -> {title, malId} for anime with episode reminders enabled.
  /// Reactive so notify toggles update the UI instantly.
  final RxMap<String, Map<String, String>> notifyAnime =
      <String, Map<String, String>>{}.obs;

  Future<StorageService> init() async {
    _migrateLegacyKeys();
    _loadFavorites();
    _loadProgress();
    _loadWatched();
    _loadNotify();
    return this;
  }

  /// One-time migration: the app shipped with un-namespaced keys and `animelok`
  /// as the default provider, so move any legacy global data into the animelok
  /// namespace (copied, not deleted) so existing users keep their favorites.
  void _migrateLegacyKeys() {
    const map = {
      'favorites': 'favorites_animelok',
      'watch_progress': 'watch_progress_animelok',
      'watched_episodes': 'watched_episodes_animelok',
      'notify_anime': 'notify_anime_animelok',
    };
    map.forEach((oldK, newK) {
      if (_box.hasData(oldK) && !_box.hasData(newK)) {
        _box.write(newK, _box.read(oldK));
      }
    });
  }

  /// Reload all per-provider lists (called when the API provider changes). The
  /// previous provider's data stays on disk under its own keys, untouched.
  void reloadForProvider() {
    _watched.clear();
    notifyAnime.clear();
    _loadFavorites();
    _loadProgress();
    _loadWatched();
    _loadNotify();
  }

  // ---------------------------------------------------------------- favorites
  void _loadFavorites() {
    final raw = (_box.read(_favoritesKey) as List?) ?? const [];
    favorites.assignAll(
      raw.whereType<Map>().map((e) => Anime.fromJson(Map<String, dynamic>.from(e))),
    );
  }

  bool isFavorite(String id) => favorites.any((a) => a.id == id);

  /// Favorites stored under a specific provider's namespace (used to clean up
  /// that provider's push topics when switching away from it).
  List<Anime> favoritesFor(String provider) {
    final raw = (_box.read('favorites_$provider') as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  void toggleFavorite(Anime anime) {
    final nowFavorite = !isFavorite(anime.id);
    if (nowFavorite) {
      favorites.insert(0, anime);
    } else {
      favorites.removeWhere((a) => a.id == anime.id);
    }
    _box.write(_favoritesKey, favorites.map((a) => a.toJson()).toList());
    // Keep the per-anime push topic in sync (no-op unless in favourites mode).
    if (Get.isRegistered<PushService>()) {
      Get.find<PushService>()
          .syncAnimeTopic(anime.title, subscribe: nowFavorite);
    }
  }

  // ----------------------------------------------------------------- progress
  void _loadProgress() {
    final raw = (_box.read(_progressKey) as List?) ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => WatchProgress.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    continueWatching.assignAll(items);
  }

  WatchProgress? progressFor(String animeId) {
    for (final p in continueWatching) {
      if (p.anime.id == animeId) return p;
    }
    return null;
  }

  void saveProgress(WatchProgress progress) {
    continueWatching.removeWhere((p) => p.anime.id == progress.anime.id);
    continueWatching.insert(0, progress);
    // Keep the list bounded.
    if (continueWatching.length > 30) {
      continueWatching.removeRange(30, continueWatching.length);
    }
    _persistProgress();
  }

  void removeProgress(String animeId) {
    continueWatching.removeWhere((p) => p.anime.id == animeId);
    _persistProgress();
  }

  void clearAllProgress() {
    continueWatching.clear();
    _persistProgress();
  }

  /// Unfinished items only — used for the "Continue Watching" rails.
  List<WatchProgress> get unfinished =>
      continueWatching.where((p) => !p.isFinished).toList();

  void _persistProgress() {
    _box.write(_progressKey, continueWatching.map((p) => p.toJson()).toList());
  }

  // ----------------------------------------------------------- watched episodes
  void _loadWatched() {
    final raw = (_box.read(_watchedKey) as Map?) ?? const {};
    raw.forEach((key, value) {
      final nums = (value as List?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};
      _watched['$key'] = nums;
    });
  }

  /// Episode numbers already watched for [animeId].
  Set<int> watchedEpisodeNumbers(String animeId) =>
      Set<int>.from(_watched[animeId] ?? const <int>{});

  void markEpisodeWatched(String animeId, int number) {
    final set = _watched.putIfAbsent(animeId, () => <int>{});
    if (set.add(number)) {
      _box.write(
        _watchedKey,
        _watched.map((k, v) => MapEntry(k, v.toList())),
      );
    }
  }

  // ------------------------------------------------------- episode reminders
  void _loadNotify() {
    final raw = (_box.read(_notifyKey) as Map?) ?? const {};
    raw.forEach((key, value) {
      if (value is Map) {
        notifyAnime['$key'] = {
          'title': '${value['title'] ?? ''}',
          'malId': '${value['malId'] ?? ''}',
        };
      }
    });
  }

  bool isNotifyEnabled(String animeId) => notifyAnime.containsKey(animeId);

  void setNotify(
    String animeId, {
    required bool enabled,
    String title = '',
    String malId = '',
  }) {
    if (enabled) {
      notifyAnime[animeId] = {'title': title, 'malId': malId};
    } else {
      notifyAnime.remove(animeId);
    }
    _box.write(_notifyKey, Map<String, dynamic>.from(notifyAnime));
  }

  // -------------------------------------------------------------- preferences
  bool get preferDub => _box.read(_preferDubKey) == true;
  set preferDub(bool value) => _box.write(_preferDubKey, value);

  /// Preferred audio language (e.g. "japanese", "english", "hindi"). Null until
  /// the user picks one in the player.
  String? get preferredLanguage => _box.read(_preferredLanguageKey) as String?;
  set preferredLanguage(String? value) =>
      _box.write(_preferredLanguageKey, value);

  /// Preferred episode-list order, remembered across all anime:
  /// true = oldest→newest (default), false = newest→oldest.
  bool get episodesAscending => _box.read(_episodesAscendingKey) as bool? ?? true;
  set episodesAscending(bool value) =>
      _box.write(_episodesAscendingKey, value);

  // ─────────────────────────────────────────────────── notification prefs
  // Default ON to match the app's current behaviour (all topics subscribed).
  static const _notifAllKey = 'notif_all';
  static const _notifEpisodesKey = 'notif_episodes';
  static const _notifWallpapersKey = 'notif_wallpapers';
  static const _notifNewsKey = 'notif_news';

  bool get notifAll => _box.read(_notifAllKey) as bool? ?? true;
  set notifAll(bool v) => _box.write(_notifAllKey, v);

  bool get notifEpisodes => _box.read(_notifEpisodesKey) as bool? ?? true;
  set notifEpisodes(bool v) => _box.write(_notifEpisodesKey, v);

  bool get notifWallpapers => _box.read(_notifWallpapersKey) as bool? ?? true;
  set notifWallpapers(bool v) => _box.write(_notifWallpapersKey, v);

  bool get notifNews => _box.read(_notifNewsKey) as bool? ?? true;
  set notifNews(bool v) => _box.write(_notifNewsKey, v);

  // Anime episode alerts: favourites-only vs all. Defaults to the requested
  // rule — no favourites → all; at least one favourite → favourites-only —
  // until the user sets it explicitly.
  static const _notifFavOnlyKey = 'notif_episodes_fav_only';
  bool get notifEpisodesFavoritesOnly =>
      _box.read(_notifFavOnlyKey) as bool? ?? favorites.isNotEmpty;
  set notifEpisodesFavoritesOnly(bool v) => _box.write(_notifFavOnlyKey, v);
}
