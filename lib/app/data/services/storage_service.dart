import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../models/anime.dart';
import '../models/watch_progress.dart';

/// Local persistence backed by GetStorage. Holds favorites, "continue
/// watching" progress and lightweight user preferences.
///
/// Exposes reactive lists so the UI updates instantly on change.
class StorageService extends GetxService {
  static const _favoritesKey = 'favorites';
  static const _progressKey = 'watch_progress';
  static const _preferDubKey = 'prefer_dub';
  static const _preferredLanguageKey = 'preferred_language';
  static const _episodesAscendingKey = 'episodes_ascending';
  static const _watchedKey = 'watched_episodes';
  static const _notifyKey = 'notify_anime';

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
    _loadFavorites();
    _loadProgress();
    _loadWatched();
    _loadNotify();
    return this;
  }

  // ---------------------------------------------------------------- favorites
  void _loadFavorites() {
    final raw = (_box.read(_favoritesKey) as List?) ?? const [];
    favorites.assignAll(
      raw.whereType<Map>().map((e) => Anime.fromJson(Map<String, dynamic>.from(e))),
    );
  }

  bool isFavorite(String id) => favorites.any((a) => a.id == id);

  void toggleFavorite(Anime anime) {
    if (isFavorite(anime.id)) {
      favorites.removeWhere((a) => a.id == anime.id);
    } else {
      favorites.insert(0, anime);
    }
    _box.write(_favoritesKey, favorites.map((a) => a.toJson()).toList());
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
}
