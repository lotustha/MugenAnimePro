import 'package:get/get.dart';

import '../../data/models/anime.dart';
import '../../data/models/paged_result.dart';
import '../../data/repositories/anime_repository.dart';
import 'category_args.dart';

/// Drives the generic paged grid used for category and genre browsing.
class CategoryController extends GetxController {
  final AnimeRepository _repo = Get.find();

  late final CategoryArgs args;

  final RxBool loading = true.obs;
  final RxBool loadingMore = false.obs;
  final RxnString error = RxnString();
  final RxList<Anime> items = <Anime>[].obs;

  int _page = 1;
  bool _hasNext = false;

  @override
  void onInit() {
    super.onInit();
    args = Get.arguments as CategoryArgs;
    load();
  }

  Future<PagedResult<Anime>> _fetch(int page) {
    switch (args.kind) {
      case CategoryKind.genre:
        return _repo.genre(args.value, page: page);
      case CategoryKind.category:
        return _repo.category(args.value, page: page);
    }
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    _page = 1;
    try {
      final res = await _fetch(_page);
      items.assignAll(res.results);
      _hasNext = res.hasNextPage;
    } catch (e) {
      error.value = '$e';
      items.clear();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !_hasNext || loading.value) return;
    loadingMore.value = true;
    try {
      final res = await _fetch(_page + 1);
      _page += 1;
      _hasNext = res.hasNextPage;
      items.addAll(res.results);
    } catch (_) {
      // Non-fatal: keep what we have.
    } finally {
      loadingMore.value = false;
    }
  }
}
