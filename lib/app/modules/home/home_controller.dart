import 'package:get/get.dart';

import '../../data/models/anime.dart';
import '../../data/models/spotlight_item.dart';
import '../../data/repositories/anime_repository.dart';

class HomeController extends GetxController {
  final AnimeRepository _repo = Get.find();

  final RxBool loading = true.obs;
  final RxnString error = RxnString();

  final RxList<SpotlightItem> spotlight = <SpotlightItem>[].obs;
  final RxList<Anime> recent = <Anime>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
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
