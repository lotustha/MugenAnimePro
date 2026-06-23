import 'package:get/get.dart';

import '../../data/models/anime.dart';
import '../../data/models/spotlight_item.dart';
import '../../data/models/watch_progress.dart';
import '../../data/repositories/anime_repository.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';
import '../watch/watch_args.dart';

class HomeController extends GetxController {
  final AnimeRepository _repo = Get.find();
  final StorageService _storage = Get.find();

  final RxBool loading = true.obs;
  final RxnString error = RxnString();

  /// True while resolving the resume target for the floating Continue button.
  final RxBool resuming = false.obs;

  final RxList<SpotlightItem> spotlight = <SpotlightItem>[].obs;
  final RxList<Anime> recent = <Anime>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Most recently watched, still-unfinished item (drives the Continue button).
  WatchProgress? get lastWatched {
    final items = _storage.unfinished;
    return items.isEmpty ? null : items.first;
  }

  /// Resume the most recently watched episode straight into the player.
  Future<void> continuePlaying() async {
    final p = lastWatched;
    if (p == null || resuming.value) return;
    resuming.value = true;
    try {
      final info = await _repo.info(p.anime.id);
      final eps = info.episodes;
      if (eps.isEmpty) throw 'No episodes available.';
      final ep = eps.firstWhere(
        (e) => e.id == p.episodeId,
        orElse: () => eps.firstWhere(
          (e) => e.number == p.episodeNumber,
          orElse: () => eps.first,
        ),
      );
      Get.toNamed(
        Routes.watch,
        arguments: WatchArgs(
          anime: info.toAnime(),
          episodes: eps,
          startEpisode: ep,
          preferDub: _storage.preferDub,
        ),
      );
    } catch (e) {
      Get.snackbar('Could not resume', '$e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      resuming.value = false;
    }
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      // Fire both requests concurrently, then await each in a type-safe way.
      final spotlightFuture = _repo.spotlight();
      final recentFuture = _repo.recentEpisodes();
      spotlight.assignAll(await spotlightFuture);
      final recentResult = await recentFuture;
      recent.assignAll(recentResult.results);
    } catch (e) {
      error.value = '$e';
    } finally {
      loading.value = false;
    }
  }
}
