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
        return ListView(
          children: [
            if (continueWatching.isNotEmpty) ...[
              const SectionHeader(title: 'Continue Watching'),
              ContinueWatchingRail(items: continueWatching),
            ],
            if (favorites.isNotEmpty) ...[
              const SectionHeader(title: 'Favorites'),
              GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: favorites.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  childAspectRatio: 0.52,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, i) => AnimeCard(
                  anime: favorites[i],
                  width: 150,
                  onTap: () =>
                      Get.toNamed(Routes.detail, arguments: favorites[i].id),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }
}
