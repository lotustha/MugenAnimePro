import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/wallpaper.dart';
import '../../data/repositories/content_repository.dart';
import 'wallpaper_card.dart';

class WallpaperSearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WallpaperSearchController>(() => WallpaperSearchController());
  }
}

class WallpaperSearchController extends GetxController {
  final ContentRepository _repo = Get.find();

  final RxString query = ''.obs;
  final RxBool loading = false.obs;
  final RxList<Wallpaper> results = <Wallpaper>[].obs;
  final RxBool searched = false.obs;

  Timer? _debounce;
  String _last = '';

  void onChanged(String value) {
    query.value = value;
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      results.clear();
      searched.value = false;
      loading.value = false;
      _last = '';
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q == _last) return;
    _last = q;
    loading.value = true;
    try {
      final res = await _repo.searchWallpapers(q);
      results.assignAll(res);
    } catch (_) {
      results.clear();
    } finally {
      searched.value = true;
      loading.value = false;
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}

class WallpaperSearchView extends StatelessWidget {
  const WallpaperSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<WallpaperSearchController>();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.primary,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search wallpapers…',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: c.onChanged,
        ),
      ),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.query.value.trim().isEmpty) {
          return const Center(
            child: Text('Type to search wallpapers',
                style: TextStyle(color: Colors.white38)),
          );
        }
        if (c.searched.value && c.results.isEmpty) {
          return const Center(
            child: Text('No results',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 9 / 16,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: c.results.length,
          itemBuilder: (_, i) => WallpaperCard(wallpaper: c.results[i]),
        );
      }),
    );
  }
}
