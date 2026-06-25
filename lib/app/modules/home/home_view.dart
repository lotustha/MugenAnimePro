import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/anime.dart';
import '../../data/models/post.dart';
import '../../data/models/spotlight_item.dart';
import '../../data/models/wallpaper.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';
import '../../widgets/anime_card.dart';
import '../../widgets/continue_watching_rail.dart';
import '../../widgets/resume_card.dart';
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
      floatingActionButton: _resumeBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              _latestNews(),
              _latestWallpapers(),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  /// Floating resume bar that continues the last-watched episode.
  Widget _resumeBar() {
    final storage = Get.find<StorageService>();
    return Obx(() {
      storage.continueWatching.length; // react to progress changes
      final p = controller.lastWatched;
      if (p == null) return const SizedBox.shrink();
      return ResumeCard(
        progress: p,
        busy: controller.resuming.value,
        onTap: controller.continuePlaying,
      );
    });
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

  /// Horizontal rail of the latest news posts, with "See all" → News list.
  Widget _latestNews() {
    return Obx(() {
      final posts = controller.latestPosts;
      if (posts.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Latest News',
            onSeeAll: () => Get.toNamed(Routes.news),
          ),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _PostRailCard(post: posts[i]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    });
  }

  /// Horizontal rail of the latest wallpapers, with "See all" → Wallpapers list.
  Widget _latestWallpapers() {
    return Obx(() {
      final wps = controller.latestWallpapers;
      if (wps.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Wallpapers',
            onSeeAll: () => Get.toNamed(Routes.wallpapers),
          ),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: wps.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(
                width: 112,
                child: _WallpaperRailCard(wallpaper: wps[i]),
              ),
            ),
          ),
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

/// Compact news card for the home "Latest News" rail.
class _PostRailCard extends StatelessWidget {
  final Post post;
  const _PostRailCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasImage = post.featuredImage != null && post.featuredImage!.isNotEmpty;
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.newsDetail, arguments: post.slug),
      child: SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: post.featuredImage!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppTheme.surfaceVariant),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppTheme.surfaceVariant),
                      )
                    : Container(
                        color: AppTheme.surfaceVariant,
                        alignment: Alignment.center,
                        child: const Icon(Icons.article,
                            color: Colors.white24, size: 28),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight wallpaper card for the home rail — shows the image (or a video
/// badge); the full looping preview lives in the Wallpapers list, keeping the
/// home feed cheap to scroll.
class _WallpaperRailCard extends StatelessWidget {
  final Wallpaper wallpaper;
  const _WallpaperRailCard({required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.wallpaperDetail, arguments: wallpaper.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (wallpaper.isVideo)
              Container(
                color: AppTheme.surfaceVariant,
                alignment: Alignment.center,
                child: const Icon(Icons.play_circle_outline,
                    color: Colors.white54, size: 28),
              )
            else
              CachedNetworkImage(
                imageUrl: wallpaper.fileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.surface),
                errorWidget: (_, __, ___) =>
                    Container(color: AppTheme.surfaceVariant),
              ),
            if (wallpaper.isVideo)
              const Positioned(
                bottom: 6,
                right: 6,
                child: Icon(Icons.videocam, color: Colors.white70, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
