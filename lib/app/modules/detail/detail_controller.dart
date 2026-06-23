import 'package:get/get.dart';

import '../../data/models/anime_info.dart';
import '../../data/models/episode.dart';
import '../../data/models/watch_progress.dart';
import '../../data/repositories/anime_repository.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';
import '../watch/watch_args.dart';

class DetailController extends GetxController {
  final AnimeRepository _repo = Get.find();
  final StorageService _storage = Get.find();

  late final String animeId;

  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final Rxn<AnimeInfo> info = Rxn<AnimeInfo>();

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
    } catch (e) {
      error.value = '$e';
    } finally {
      loading.value = false;
    }
  }

  bool get isFavorite =>
      info.value != null && _storage.isFavorite(info.value!.id);

  void toggleFavorite() {
    final i = info.value;
    if (i == null) return;
    _storage.toggleFavorite(i.toAnime());
    info.refresh();
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
}
