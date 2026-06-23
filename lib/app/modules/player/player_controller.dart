import 'dart:async';

import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/models/anime.dart';
import '../../data/models/episode.dart';
import '../../data/models/watch_progress.dart';
import '../../data/models/watch_response.dart';
import '../../data/repositories/anime_repository.dart';
import '../../data/services/storage_service.dart';
import 'player_args.dart';

class PlayerController extends GetxController {
  final AnimeRepository _repo = Get.find();
  final StorageService _storage = Get.find();

  late final Anime anime;
  late final List<Episode> episodes;
  late final bool preferDub;

  late final Player player;
  late final VideoController videoController;

  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final Rx<Episode?> current = Rx<Episode?>(null);
  final RxString serverName = ''.obs;
  final RxBool canSkip = false.obs; // inside intro/outro window

  WatchResponse? _watch;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  final List<StreamSubscription> _subs = [];
  Timer? _saveTimer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as PlayerArgs;
    anime = args.anime;
    episodes = args.episodes;
    preferDub = args.preferDub;
    player = Player();
    videoController = VideoController(player);
    _wireStreams();
    _loadEpisode(args.startEpisode, resume: true);
  }

  void _wireStreams() {
    _subs.add(player.stream.position.listen((p) {
      position.value = p;
      _updateSkip();
    }));
    _subs.add(player.stream.duration.listen((d) => duration.value = d));
    _subs.add(player.stream.error.listen((e) {
      if (loading.value) {
        error.value = 'Playback error: $e';
        loading.value = false;
      }
    }));
    _subs.add(player.stream.completed.listen((done) {
      if (done && duration.value.inSeconds > 0) {
        _saveProgress();
        playNext();
      }
    }));
    // Persist progress periodically.
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  int get _currentIndex {
    final c = current.value;
    if (c == null) return -1;
    return episodes.indexWhere((e) => e.id == c.id);
  }

  bool get hasNext => _currentIndex >= 0 && _currentIndex < episodes.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  Future<void> playNext() async {
    if (!hasNext) return;
    await _loadEpisode(episodes[_currentIndex + 1]);
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    await _loadEpisode(episodes[_currentIndex - 1]);
  }

  Future<void> _loadEpisode(Episode ep, {bool resume = false}) async {
    loading.value = true;
    error.value = null;
    current.value = ep;
    canSkip.value = false;
    try {
      final watch = await _repo.watch(ep.id);
      _watch = watch;
      final server = watch.playableServer;
      final source = server?.hlsSource;
      if (server == null || source == null || source.file.isEmpty) {
        throw 'No playable source for this episode.';
      }
      serverName.value = server.name;

      await player.open(
        Media(source.file, httpHeaders: server.headers),
        play: true,
      );

      // Attach English subtitle if present (HardSub servers may have none).
      Subtitle? sub;
      for (final s in server.subtitles) {
        if (s.isEnglish) {
          sub = s;
          break;
        }
      }
      sub ??= server.subtitles.isNotEmpty ? server.subtitles.first : null;
      if (sub != null && sub.url.isNotEmpty) {
        await player.setSubtitleTrack(
          SubtitleTrack.uri(sub.url, title: sub.lang, language: sub.lang),
        );
      }

      // Resume position from saved progress for this anime/episode.
      if (resume) {
        final p = _storage.progressFor(anime.id);
        if (p != null && p.episodeId == ep.id && p.positionMs > 5000 && !p.isFinished) {
          await player.seek(Duration(milliseconds: p.positionMs));
        }
      }
      loading.value = false;
    } catch (e) {
      error.value = '$e';
      loading.value = false;
    }
  }

  void _updateSkip() {
    final w = _watch;
    if (w == null) {
      canSkip.value = false;
      return;
    }
    final secs = position.value.inSeconds;
    canSkip.value =
        (w.intro?.contains(secs) ?? false) || (w.outro?.contains(secs) ?? false);
  }

  void skipSegment() {
    final w = _watch;
    if (w == null) return;
    final secs = position.value.inSeconds;
    if (w.intro?.contains(secs) ?? false) {
      player.seek(Duration(seconds: w.intro!.end));
    } else if (w.outro?.contains(secs) ?? false) {
      player.seek(Duration(seconds: w.outro!.end));
    }
  }

  void seekRelative(int seconds) {
    final target = position.value + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration.value ? duration.value : target);
    player.seek(clamped);
  }

  void _saveProgress() {
    final ep = current.value;
    if (ep == null) return;
    final pos = position.value.inMilliseconds;
    final dur = duration.value.inMilliseconds;
    if (dur <= 0 || pos <= 0) return;
    _storage.saveProgress(WatchProgress(
      anime: anime,
      episodeId: ep.id,
      episodeNumber: ep.number,
      positionMs: pos,
      durationMs: dur,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void retry() {
    final ep = current.value;
    if (ep != null) _loadEpisode(ep);
  }

  @override
  void onClose() {
    _saveProgress();
    _saveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    super.onClose();
  }
}
