import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/app_theme.dart';
import '../data/models/watch_progress.dart';
import '../routes/app_pages.dart';
import 'poster_image.dart';

/// Horizontal rail of in-progress episodes. Shared by Home and Library.
class ContinueWatchingRail extends StatelessWidget {
  final List<WatchProgress> items;
  const ContinueWatchingRail({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _ContinueCard(progress: items[i]),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final WatchProgress progress;
  const _ContinueCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.detail, arguments: progress.anime.id),
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: PosterImage(url: progress.anime.image, width: 260),
                  ),
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_fill,
                          size: 44, color: Colors.white70),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 4,
                      backgroundColor: Colors.black54,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(progress.anime.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('Episode ${progress.episodeNumber}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
