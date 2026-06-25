import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/anime_info.dart';
import '../../data/models/episode.dart';
import '../../data/models/next_airing.dart';
import '../../data/models/watch_progress.dart';
import '../../data/providers/anilist_client.dart';
import '../../data/repositories/anime_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';
import '../watch/watch_args.dart';

class DetailController extends GetxController {
  final AnimeRepository _repo = Get.find();
  final StorageService _storage = Get.find();
  final AniListClient _aniList = Get.find();
  final NotificationService _notifications = Get.find();

  late String animeId;

  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final Rxn<AnimeInfo> info = Rxn<AnimeInfo>();

  /// Next airing episode for currently-airing anime, or null. Drives the
  /// countdown card; [nowTick] bumps once a minute so the countdown stays live.
  final Rxn<NextAiringEpisode> nextAiring = Rxn<NextAiringEpisode>();
  final RxInt nowTick = 0.obs;
  Timer? _ticker;

  /// Preferred audio for playback. false = SUB, true = DUB.
  final RxBool dubSelected = false.obs;

  @override
  void onInit() {
    super.onInit();
    animeId = Get.arguments as String;
    dubSelected.value = _storage.preferDub;
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final result = await _repo.info(animeId);
      info.value = result;
      // Default audio to whatever is available.
      if (!result.hasDub) dubSelected.value = false;
      if (!result.hasSub && result.hasDub) dubSelected.value = true;
      _loadNextAiring(result);
    } catch (e) {
      error.value = '$e';
    } finally {
      loading.value = false;
    }
  }

  /// Open a related/recommended anime in place (reuse this page) instead of
  /// pushing a new detail route.
  ///
  /// Navigating detail→detail re-runs DetailBinding, but `Get.lazyPut` won't
  /// replace the still-registered controller, so the rebuilt page resolves THIS
  /// (stale) controller and shows the previous anime until the old instance is
  /// disposed — the "have to tap twice" bug. Reloading here is deterministic.
  /// `load()` flips `loading` on, which swaps the scroll view for the loader and
  /// rebuilds it fresh, so the page also scrolls back to the top for free.
  Future<void> openRelated(String id) async {
    if (id.isEmpty || id == animeId) return;
    animeId = id;
    nextAiring.value = null;
    _ticker?.cancel();
    _ticker = null;
    dubSelected.value = _storage.preferDub;
    await load();
  }

  /// Resolve the next airing episode via AniList (best-effort) and start a
  /// per-minute ticker so the countdown stays current.
  Future<void> _loadNextAiring(AnimeInfo result) async {
    final malId = int.tryParse(result.malId ?? '');
    if (malId == null) return;
    final next = await _aniList.nextAiring(malId);
    if (next == null) return;
    nextAiring.value = next;
    _ticker ??= Timer.periodic(const Duration(minutes: 1), (_) => nowTick.value++);
    // If reminders are already on for this anime, refresh to the latest time.
    if (_storage.isNotifyEnabled(animeId)) {
      _notifications.scheduleEpisode(
        animeId: animeId,
        title: result.title,
        episode: next.episode,
        airAt: next.airingAt,
      );
    }
  }

  /// Whether episode reminders are enabled for this anime (reactive).
  bool get notifyOn => _storage.notifyAnime.containsKey(animeId);

  /// Toggle "notify me when a new episode airs" for this anime (manual bell).
  Future<void> toggleNotify() async {
    final i = info.value;
    if (i == null) return;
    if (_storage.isNotifyEnabled(animeId)) {
      await _disableNotify();
      Get.snackbar('Reminders off', 'You won\'t be notified for ${i.title}');
      return;
    }
    final granted = await _enableNotify(i);
    if (!granted) {
      Get.snackbar('Permission needed',
          'Enable notifications in system settings to get reminders');
      return;
    }
    final next = nextAiring.value;
    Get.snackbar(
      'Reminder set',
      next != null
          ? 'We\'ll alert you when E${next.episode} airs'
          : 'We\'ll remind you when a new episode is scheduled',
    );
  }

  /// Enable reminders for [i]. Returns false if permission was denied.
  Future<bool> _enableNotify(AnimeInfo i) async {
    final granted = await _notifications.requestPermission();
    if (!granted) return false;
    _storage.setNotify(animeId,
        enabled: true, title: i.title, malId: i.malId ?? '');
    final next = nextAiring.value;
    if (next != null) {
      await _notifications.scheduleEpisode(
        animeId: animeId,
        title: i.title,
        episode: next.episode,
        airAt: next.airingAt,
      );
    }
    return true;
  }

  Future<void> _disableNotify() async {
    _storage.setNotify(animeId, enabled: false);
    await _notifications.cancel(animeId);
  }

  bool get isFavorite =>
      info.value != null && _storage.isFavorite(info.value!.id);

  /// Toggle favorite. Favoriting also turns on episode reminders (and
  /// un-favoriting turns them off) so the user is notified for everything in
  /// their favorites.
  void toggleFavorite() {
    final i = info.value;
    if (i == null) return;
    final wasFavorite = _storage.isFavorite(i.id);
    _storage.toggleFavorite(i.toAnime());
    info.refresh();
    if (wasFavorite) {
      _disableNotify();
    } else {
      _enableNotify(i);
    }
  }

  WatchProgress? get progress => _storage.progressFor(animeId);

  /// Episode number to resume from, or null if nothing watched yet.
  int? get resumeEpisodeNumber => progress?.episodeNumber;

  void playEpisode(Episode ep) {
    final i = info.value;
    if (i == null) return;
    Get.toNamed(
      Routes.watch,
      arguments: WatchArgs(
        anime: i.toAnime(),
        episodes: i.episodes,
        startEpisode: ep,
        preferDub: dubSelected.value,
      ),
    );
  }

  void resumeOrStart() {
    final eps = info.value?.episodes ?? const <Episode>[];
    if (eps.isEmpty) return;
    final resumeNum = resumeEpisodeNumber;
    final ep = resumeNum == null
        ? eps.first
        : eps.firstWhere((e) => e.number == resumeNum, orElse: () => eps.first);
    playEpisode(ep);
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }
}
