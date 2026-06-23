import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/anime.dart';
import '../../data/models/spotlight_item.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';
import '../../widgets/anime_card.dart';
import '../../widgets/continue_watching_rail.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import 'home_controller.dart';
import 'widgets/spotlight_carousel.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  void _openDetail(String id) => Get.toNamed(Routes.detail, arguments: id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimeStream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed(Routes.search),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) return const LoadingView();
        if (controller.error.value != null) {
          return ErrorRetryView(
            message: controller.error.value!,
            onRetry: controller.load,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            children: [
              if (controller.spotlight.isNotEmpty)
                SpotlightCarousel(
                  items: controller.spotlight,
                  onTap: (SpotlightItem s) => _openDetail(s.id),
                ),
              _continueWatching(),
              const SectionHeader(title: 'Recently Updated'),
              _recentGrid(controller.recent),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  Widget _continueWatching() {
    final storage = Get.find<StorageService>();
    return Obx(() {
      final items = storage.unfinished;
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Continue Watching',
            onSeeAll: () => Get.toNamed(Routes.history),
          ),
          ContinueWatchingRail(items: items),
          const SizedBox(height: 8),
        ],
      );
    });
  }

  Widget _recentGrid(List<Anime> items) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.52,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) => AnimeCard(
        anime: items[i],
        width: 150,
        onTap: () => _openDetail(items[i].id),
      ),
    );
  }
}
