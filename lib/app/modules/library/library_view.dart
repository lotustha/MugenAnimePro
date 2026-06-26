import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';
import '../../widgets/anime_card.dart';
import '../../widgets/continue_watching_rail.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            tooltip: 'Watch history',
            icon: const Icon(Icons.history),
            onPressed: () => Get.toNamed(Routes.history),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Get.toNamed(Routes.settings),
          ),
        ],
      ),
      body: Obx(() {
        final continueWatching = storage.unfinished;
        final favorites = storage.favorites;
        if (continueWatching.isEmpty && favorites.isEmpty) {
          return const EmptyView(
            message: 'Nothing here yet.\nStart watching to build your library.',
            icon: Icons.video_library_outlined,
          );
        }
        // CustomScrollView so the favorites grid virtualizes as a SliverGrid
        // instead of a shrink-wrapped GridView that builds every card at once.
        return CustomScrollView(
          slivers: [
            if (continueWatching.isNotEmpty) ...[
              const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Continue Watching')),
              SliverToBoxAdapter(
                  child: ContinueWatchingRail(items: continueWatching)),
            ],
            if (favorites.isNotEmpty) ...[
              const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Favorites')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    childAspectRatio: 0.52,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AnimeCard(
                      anime: favorites[i],
                      width: 150,
                      onTap: () => Get.toNamed(Routes.detail,
                          arguments: favorites[i].id),
                    ),
                    childCount: favorites.length,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      }),
    );
  }
}
