import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/wallpaper.dart';
import '../../data/models/wallpaper_category.dart';
import '../../data/repositories/content_repository.dart';
import '../../routes/app_pages.dart';
import 'wallpaper_card.dart';

class WallpapersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WallpapersController>(() => WallpapersController());
  }
}

class WallpapersController extends GetxController {
  final ContentRepository _repo = Get.find();

  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxnString error = RxnString();
  final RxList<Wallpaper> items = <Wallpaper>[].obs;

  final RxList<WallpaperCategory> categories = <WallpaperCategory>[].obs;
  final RxnString selectedCategory = RxnString(); // slug; null = All

  int _page = 1;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
    refreshList();
  }

  Future<void> _loadCategories() async {
    try {
      categories.assignAll(await _repo.wallpaperCategories());
    } catch (_) {
      // categories are optional — grid still works without them
    }
  }

  void selectCategory(String? slug) {
    if (selectedCategory.value == slug) return;
    selectedCategory.value = slug;
    refreshList();
  }

  Future<void> refreshList() async {
    loading.value = true;
    error.value = null;
    _page = 1;
    _hasMore = true;
    try {
      final res = await _repo.wallpapers(page: 1, category: selectedCategory.value);
      items.assignAll(res);
      _hasMore = res.isNotEmpty;
    } catch (e) {
      error.value = '$e';
      items.clear();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !_hasMore || loading.value) return;
    loadingMore.value = true;
    try {
      final res =
          await _repo.wallpapers(page: _page + 1, category: selectedCategory.value);
      _page += 1;
      if (res.isEmpty) {
        _hasMore = false;
      } else {
        items.addAll(res);
      }
    } catch (_) {
      // non-fatal
    } finally {
      loadingMore.value = false;
    }
  }
}

class WallpapersView extends StatelessWidget {
  const WallpapersView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<WallpapersController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpapers'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed(Routes.wallpaperSearch),
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryBar(controller: c),
          Expanded(
            child: Obx(() {
              if (c.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.error.value != null && c.items.isEmpty) {
                return _ErrorState(message: c.error.value!, onRetry: c.refreshList);
              }
              if (c.items.isEmpty) {
                return const Center(
                  child: Text('No wallpapers here',
                      style: TextStyle(color: Colors.white38)),
                );
              }
              return RefreshIndicator(
                onRefresh: c.refreshList,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
                      c.loadMore();
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 9 / 16,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: c.items.length,
                    itemBuilder: (_, i) => WallpaperCard(wallpaper: c.items[i]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final WallpapersController controller;
  const _CategoryBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.categories.isEmpty) return const SizedBox.shrink();
      final selected = controller.selectedCategory.value;
      return SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _Chip(
              label: 'All',
              active: selected == null,
              onTap: () => controller.selectCategory(null),
            ),
            for (final cat in controller.categories)
              _Chip(
                label: cat.name,
                active: selected == cat.slug,
                onTap: () => controller.selectCategory(cat.slug),
              ),
          ],
        ),
      );
    });
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
