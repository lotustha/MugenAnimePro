import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/anime.dart';
import '../../data/repositories/anime_repository.dart';

class SearchScreenController extends GetxController {
  final AnimeRepository _repo = Get.find();

  final RxString query = ''.obs;
  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxnString error = RxnString();
  final RxList<Anime> results = <Anime>[].obs;

  int _page = 1;
  bool _hasNext = false;
  Timer? _debounce;

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      results.clear();
      error.value = null;
      loading.value = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(trimmed));
  }

  Future<void> _search(String q) async {
    loading.value = true;
    error.value = null;
    _page = 1;
    try {
      final res = await _repo.search(q, page: _page);
      results.assignAll(res.results);
      _hasNext = res.hasNextPage;
    } catch (e) {
      error.value = '$e';
      results.clear();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !_hasNext) return;
    final q = query.value.trim();
    if (q.isEmpty) return;
    loadingMore.value = true;
    try {
      final res = await _repo.search(q, page: _page + 1);
      _page += 1;
      _hasNext = res.hasNextPage;
      results.addAll(res.results);
    } catch (_) {
      // Keep existing results; pagination failure is non-fatal.
    } finally {
      loadingMore.value = false;
    }
  }

  void retry() {
    final q = query.value.trim();
    if (q.isNotEmpty) _search(q);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
